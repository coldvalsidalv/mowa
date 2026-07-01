/**
 * seed.mjs — загружает vocabulary и grammar_lessons в Teenybase
 * Запуск: node backend/scripts/seed.mjs
 */

import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '../..')

const DB_URL = process.env.DB_URL ?? 'http://localhost:8787'
const TOKEN  = process.env.TOKEN  ?? 'verbum-local-admin-token-change-in-prod'

const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${TOKEN}`,
}

// ─── helpers ──────────────────────────────────────────────────────────────────

async function insert(table, values) {
  const res = await fetch(`${DB_URL}/api/v1/table/${table}/insert`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ values, returning: 'id' }),
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`${table} insert failed ${res.status}: ${text}`)
  }
  return res.json()
}

async function batchInsert(table, rows, batchSize = 50) {
  let done = 0
  for (let i = 0; i < rows.length; i += batchSize) {
    const batch = rows.slice(i, i + batchSize)
    await Promise.all(batch.map(r => insert(table, r)))
    done += batch.length
    process.stdout.write(`\r  ${table}: ${done}/${rows.length}`)
  }
  console.log()
}

// ─── vocabulary ───────────────────────────────────────────────────────────────

async function seedVocabulary() {
  console.log('→ Seeding vocabulary...')
  const raw = JSON.parse(readFileSync(resolve(ROOT, 'Resources/words.json'), 'utf8'))

  const rows = raw.map(w => ({
    polish:        w.polish,
    translation:   w.translation,
    transcription: w.transcription ?? '',
    part_of_speech: w.partOfSpeech ?? '',
    example:       w.example ?? '',
    examples_list: JSON.stringify(w.examplesList ?? []),
    category:      w.category,
    level:         '',
    image_name:    w.imageName ?? '',
  }))

  await batchInsert('vocabulary', rows)
  console.log(`✓ vocabulary: ${rows.length} words`)
}

// ─── grammar ──────────────────────────────────────────────────────────────────

async function seedGrammar() {
  console.log('→ Seeding grammar_lessons...')
  const raw = JSON.parse(readFileSync(resolve(ROOT, 'Resources/grammar.json'), 'utf8'))

  const rows = raw.map((lesson, idx) => ({
    lesson_id:   lesson.id,
    title:       lesson.title,
    description: lesson.description ?? '',
    level:       lesson.level,
    order_index: idx,
    steps:       JSON.stringify(lesson.steps),
  }))

  await batchInsert('grammar_lessons', rows)
  console.log(`✓ grammar_lessons: ${rows.length} lessons`)
}

// ─── main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`Seeding ${DB_URL}...\n`)

  // Проверяем что бэкенд доступен
  const health = await fetch(`${DB_URL}/api/v1/health`).catch(() => null)
  if (!health?.ok) {
    console.error('✗ Backend not reachable at', DB_URL)
    console.error('  Run: npm run dev (in backend/)')
    process.exit(1)
  }

  await seedVocabulary()
  await seedGrammar()

  console.log('\n✓ Seed complete')
}

main().catch(e => { console.error(e); process.exit(1) })
