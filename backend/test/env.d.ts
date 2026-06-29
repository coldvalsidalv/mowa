import type { D1Migration } from '@cloudflare/vitest-pool-workers'

declare module 'cloudflare:test' {
  interface ProvidedEnv {
    PRIMARY_DB: D1Database
    TEST_MIGRATIONS: D1Migration[]
    JWT_SECRET: string
    JWT_SECRET_USERS: string
  }
}
