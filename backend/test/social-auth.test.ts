import { env, applyD1Migrations, SELF } from 'cloudflare:test'
import { beforeAll, describe, expect, it } from 'vitest'
import { sign } from '@tsndr/cloudflare-worker-jwt'

// Security tests for the external-token login path (Sign in with Apple / Google
// both go through /auth/login-token). Real Apple/Google tokens can't be minted in
// tests, so the flow is exercised through the 'test-e2e' issuer from teenybase.ts:
// same code path (issuerMap → verifyExternalToken → _loginWithExternalUser), but
// HS256-signed with a secret that exists only in vitest.config.mts.
//
// The forged Apple/Google cases assert the security property `res.ok === false`
// rather than an exact status: with network access they fail signature/JWKS checks
// (401); without network the JWKS/tokeninfo fetch fails (5xx). Either way they
// must never authenticate.

const ORIGIN = 'https://social.test'
const AUTH = `${ORIGIN}/api/v1/table/users/auth`

const TEST_ISSUER = 'verbum-test-issuer'
const TEST_SECRET = 'vitest-issuer-hmac-secret'
const TEST_AUD = 'verbum-test-aud'

beforeAll(async () => {
  await applyD1Migrations(env.PRIMARY_DB, env.TEST_MIGRATIONS)
  // teenybase stores auth sessions in an internal KV table created by teeny
  // setup, not by a generated migration file — create it for the test DB.
  await env.PRIMARY_DB.exec(
    'CREATE TABLE IF NOT EXISTS _ddb_internal_kv (key TEXT PRIMARY KEY, value TEXT NOT NULL, expiry INTEGER NULL)',
  )
})

function uniqueEmail(prefix: string): string {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}@example.com`
}

type Claims = Record<string, unknown>

async function externalToken(overrides: Claims = {}, secret: string = TEST_SECRET): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  return sign(
    {
      iss: TEST_ISSUER,
      aud: TEST_AUD,
      sub: 'ext-user',
      email: 'unused@example.com',
      email_verified: true,
      iat: now,
      exp: now + 300,
      ...overrides,
    },
    secret,
    { algorithm: 'HS256' },
  )
}

async function loginToken(token?: string): Promise<Response> {
  // teenybase requires Content-Type on this route even though it reads no body;
  // the iOS client (AuthManager.postAuth) always sends it, so mirror that here.
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (token) headers.Authorization = `Bearer ${token}`
  return SELF.fetch(`${AUTH}/login-token`, { method: 'POST', headers })
}

interface AuthResponse {
  token?: string
  refresh_token?: string
  record?: { id?: string; email?: string }
}

describe('login-token: rejects everything that is not a valid provider token', () => {
  it('no Authorization header', async () => {
    const res = await loginToken()
    expect(res.ok).toBe(false)
  })

  it('malformed token', async () => {
    const res = await loginToken('not.a.jwt')
    expect(res.status).toBe(401)
  })

  it('unknown issuer', async () => {
    const res = await loginToken(await externalToken({ iss: 'https://evil.example.com' }))
    expect(res.status).toBe(401)
  })

  it('wrong HMAC secret (forged signature)', async () => {
    const res = await loginToken(await externalToken({}, 'attacker-guessed-secret'))
    expect(res.status).toBe(401)
  })

  it('expired token', async () => {
    const now = Math.floor(Date.now() / 1000)
    const res = await loginToken(await externalToken({ iat: now - 7200, exp: now - 3600 }))
    expect(res.status).toBe(401)
  })

  it('wrong audience', async () => {
    const res = await loginToken(await externalToken({ aud: 'some-other-app' }))
    expect(res.status).toBe(401)
  })

  it('unverified email claim', async () => {
    const res = await loginToken(await externalToken({ email_verified: false }))
    expect(res.ok).toBe(false)
  })

  it('self-issued session token is not accepted as a provider token', async () => {
    // A leaked Verbum access token must not mint fresh sessions through login-token.
    const suffix = Math.random().toString(36).slice(2, 10)
    const signUp = await SELF.fetch(`${AUTH}/sign-up`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: `uself${suffix}`,
        email: uniqueEmail('self'),
        password: 'password-123',
        name: 'Self',
      }),
    })
    const { token } = (await signUp.json()) as AuthResponse
    expect(token).toBeTruthy()
    const res = await loginToken(token)
    expect(res.ok).toBe(false)
  })

  it('forged Apple token never authenticates (signature/JWKS check)', async () => {
    const now = Math.floor(Date.now() / 1000)
    const res = await loginToken(
      await externalToken(
        {
          iss: 'https://appleid.apple.com',
          aud: 'com.coldvalsidalv.Verbum',
          email: 'victim@privaterelay.appleid.com',
          iat: now,
          exp: now + 300,
        },
        'not-apples-private-key',
      ),
    )
    expect(res.ok).toBe(false)
  })

  it('forged Google token never authenticates (tokeninfo check)', async () => {
    const now = Math.floor(Date.now() / 1000)
    const res = await loginToken(
      await externalToken(
        {
          iss: 'https://accounts.google.com',
          aud: 'whatever',
          email: 'victim@gmail.com',
          iat: now,
          exp: now + 300,
        },
        'not-googles-private-key',
      ),
    )
    expect(res.ok).toBe(false)
  })
})

describe('login-token: happy path and account linking', () => {
  it('valid token creates a user and returns a session', async () => {
    const email = uniqueEmail('happy')
    const res = await loginToken(await externalToken({ email }))
    expect(res.status, await res.clone().text()).toBe(200)
    const json = (await res.json()) as AuthResponse
    expect(json.token).toBeTruthy()
    expect(json.refresh_token).toBeTruthy()
    expect(json.record?.id).toBeTruthy()
    expect(json.record?.email).toBe(email)
  })

  it('second login with the same email reuses the same account', async () => {
    const email = uniqueEmail('repeat')
    const first = (await (await loginToken(await externalToken({ email }))).json()) as AuthResponse
    const second = (await (await loginToken(await externalToken({ email }))).json()) as AuthResponse
    expect(first.record?.id).toBeTruthy()
    expect(second.record?.id).toBe(first.record?.id)
  })

  it('session token from login-token authorizes table reads', async () => {
    const email = uniqueEmail('session')
    const { token } = (await (await loginToken(await externalToken({ email }))).json()) as AuthResponse
    const res = await SELF.fetch(`${ORIGIN}/api/v1/table/vocabulary/list`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ limit: 1 }),
    })
    expect(res.status).toBe(200)
  })

  // KNOWN ACCEPTED RISK (pre-account-takeover): password sign-up does not verify
  // email ownership, and external login links by email. An attacker who registers
  // victim@example.com with a password BEFORE the victim's first social login owns
  // an account the victim will be logged into. Fix lands with the email
  // verification phase; this test documents today's behavior so the risk is
  // visible and the linking semantics don't change silently.
  it('DOCUMENTS RISK: social login links into a pre-existing unverified password account', async () => {
    const email = uniqueEmail('prehijack')
    const suffix = Math.random().toString(36).slice(2, 10)
    const signUp = await SELF.fetch(`${AUTH}/sign-up`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: `uhijack${suffix}`,
        email,
        password: 'attacker-password-123',
        name: 'Attacker',
      }),
    })
    const attacker = (await signUp.json()) as AuthResponse
    expect(attacker.record?.id).toBeTruthy()

    const victim = (await (await loginToken(await externalToken({ email }))).json()) as AuthResponse
    expect(victim.record?.id).toBe(attacker.record?.id)
  })
})
