import { env, applyD1Migrations, SELF } from 'cloudflare:test'
import { beforeAll, describe, expect, it } from 'vitest'

// Canary for the manual JWT verification in src/writing.ts. That route rebuilds
// teenybase's signing key as JWT_SECRET + JWT_SECRET_USERS by hand — a private
// detail of teenybase. If teenybase ever changes how it signs auth tokens, this
// test goes red: a real teenybase-minted token would stop verifying and every
// /writing/grade call would 401.
//
// The check is end-to-end on purpose: we mint the token via the real sign-up
// flow (not by signing one ourselves), so the assertion proves the verify key
// matches what teenybase actually produces — not just that our own assumption is
// internally consistent.

const ORIGIN = 'https://canary.test'
const GRADE = `${ORIGIN}/api/v1/writing/grade`

beforeAll(async () => {
  await applyD1Migrations(env.PRIMARY_DB, env.TEST_MIGRATIONS)
  // teenybase stores auth sessions in an internal KV table created by teeny
  // setup, not by a generated migration file — create it for the test DB.
  await env.PRIMARY_DB.exec(
    'CREATE TABLE IF NOT EXISTS _ddb_internal_kv (key TEXT PRIMARY KEY, value TEXT NOT NULL, expiry INTEGER NULL)',
  )
})

async function signUpAndGetToken(): Promise<string> {
  const suffix = Math.random().toString(36).slice(2, 10)
  const res = await SELF.fetch(`${ORIGIN}/api/v1/table/users/auth/sign-up`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username: `ucanary${suffix}`,
      email: `canary_${suffix}@example.com`,
      password: 'canary-password-123',
      name: 'Canary',
    }),
  })
  expect(res.status, `sign-up failed: ${await res.clone().text()}`).toBeLessThan(300)
  const json = (await res.json()) as { token?: string }
  expect(json.token, 'sign-up did not return a token').toBeTruthy()
  return json.token!
}

describe('writing/grade auth', () => {
  it('returns 401 with no Authorization header', async () => {
    const res = await SELF.fetch(GRADE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ task_id: 'b1_hobby', text: 'x', feedback_lang: 'ru' }),
    })
    expect(res.status).toBe(401)
  })

  it('returns 401 for a malformed bearer token', async () => {
    const res = await SELF.fetch(GRADE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer not.a.jwt' },
      body: JSON.stringify({ task_id: 'b1_hobby', text: 'x' }),
    })
    expect(res.status).toBe(401)
  })

  it('accepts a real teenybase-minted token (passes auth, no 401)', async () => {
    const token = await signUpAndGetToken()
    // Unknown task_id makes the handler return 400 AFTER the auth gate and BEFORE
    // any LLM call — isolating the auth check without spending a Gemini request.
    const res = await SELF.fetch(GRADE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ task_id: '__no_such_task__', text: 'x' }),
    })
    expect(res.status, `expected non-401, got ${res.status}: ${await res.clone().text()}`).not.toBe(401)
    expect(res.status).toBe(400)
  })
})
