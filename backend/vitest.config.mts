import { defineConfig } from 'vitest/config'
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-pool-workers'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = fileURLToPath(new URL('.', import.meta.url))

// Runs the real worker (src/index.ts) in workerd. `virtual:teenybase` is teeny's
// build-time alias to the config file (see tsconfig paths); replicate it here so
// the worker resolves the same DatabaseSettings outside the teeny dev pipeline.
export default defineConfig(async () => {
  const migrations = await readD1Migrations(path.join(here, 'migrations'))
  return {
    resolve: {
      alias: { 'virtual:teenybase': path.join(here, 'teenybase.ts') },
    },
    plugins: [
      cloudflareTest({
        main: './src/index.ts',
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          compatibilityDate: '2024-01-01',
          compatibilityFlags: ['nodejs_compat'],
          // Secrets live in .dev.vars (not loaded by the pool) — inject explicitly.
          // Values are arbitrary; the canary only checks that the SAME key
          // teenybase signs with verifies in writing.ts.
          bindings: {
            TEST_MIGRATIONS: migrations,
            JWT_SECRET: 'canary-top-secret',
            JWT_SECRET_USERS: 'canary-users-secret',
            WRITING_DAILY_LIMIT: '1000',
            // Enables the 'test-e2e' external issuer from teenybase.ts.
            // Never set these in a deployed worker — without them the issuer is dead.
            TEST_ISSUER_SECRET: 'vitest-issuer-hmac-secret',
            TEST_ISSUER_AUDIENCE: 'verbum-test-aud',
          },
        },
      }),
    ],
  }
})
