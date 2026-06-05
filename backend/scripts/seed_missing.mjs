/**
 * seed_missing.mjs — вставляет только слова, которых нет в БД (по полю polish)
 * Запуск: node backend/scripts/seed_missing.mjs
 */

import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '../..')

const DB_URL = 'http://127.0.0.1:8787'
const TOKEN  = 'verbum-local-admin-token-change-in-prod'

const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${TOKEN}`,
}

async function fetchAllExisting() {
  const pageSize = 500
  const first = await fetch(`${DB_URL}/api/v1/table/vocabulary/list`, {
    method: 'POST', headers,
    body: JSON.stringify({ limit: pageSize, offset: 0 }),
  }).then(r => r.json())

  let items = first.items
  const total = first.total
  const pages = Math.ceil(total / pageSize)

  for (let p = 2; p <= pages; p++) {
    const resp = await fetch(`${DB_URL}/api/v1/table/vocabulary/list`, {
      method: 'POST', headers,
      body: JSON.stringify({ limit: pageSize, offset: (p - 1) * pageSize }),
    }).then(r => r.json())
    items = items.concat(resp.items)
  }

  return new Set(items.map(w => w.polish))
}

async function insert(row) {
  const res = await fetch(`${DB_URL}/api/v1/table/vocabulary/insert`, {
    method: 'POST', headers,
    body: JSON.stringify({ values: row }),
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`insert failed ${res.status}: ${text}`)
  }
}

async function main() {
  const health = await fetch(`${DB_URL}/api/v1/health`).catch(() => null)
  if (!health?.ok) {
    console.error('✗ Backend not reachable at', DB_URL, '— run: npm run dev')
    process.exit(1)
  }

  console.log('→ Fetching existing words from DB...')
  const existing = await fetchAllExisting()
  console.log(`  DB has ${existing.size} words`)

  const all = JSON.parse(readFileSync(resolve(ROOT, 'Resources/words.json'), 'utf8'))
  const missing = all.filter(w => !existing.has(w.polish))
  console.log(`  Bundle has ${all.length} words, missing: ${missing.length}`)

  if (missing.length === 0) {
    console.log('✓ Nothing to insert')
    return
  }

  let done = 0
  const CONCURRENCY = 20
  for (let i = 0; i < missing.length; i += CONCURRENCY) {
    const batch = missing.slice(i, i + CONCURRENCY)
    await Promise.all(batch.map(w => insert({
      polish:         w.polish,
      translation:    w.translation,
      transcription:  w.transcription ?? '',
      part_of_speech: w.partOfSpeech ?? '',
      example:        w.example ?? '',
      examples_list:  JSON.stringify(w.examplesList ?? []),
      category:       w.category,
      level:          w.level ?? '',
      image_name:     w.imageName ?? '',
    })))
    done += batch.length
    process.stdout.write(`\r  inserted: ${done}/${missing.length}`)
  }
  console.log(`\n✓ Done — DB now has ${existing.size + missing.length} words`)
}

main().catch(e => { console.error(e); process.exit(1) })
