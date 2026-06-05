/**
 * sync_categories_to_db.mjs — синхронизирует category и rank из words.json в Teenybase DB.
 * Матчинг по полю polish (уникальное для каждого слова).
 * Запуск: node backend/scripts/sync_categories_to_db.mjs
 */

import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT      = resolve(__dirname, '../..')
const DB_URL    = 'http://127.0.0.1:8787'
const TOKEN     = 'verbum-local-admin-token-change-in-prod'
const HEADERS   = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${TOKEN}` }
const CONCURRENCY = 30

async function fetchAll() {
  const resp = await fetch(`${DB_URL}/api/v1/table/vocabulary/list`, {
    method: 'POST', headers: HEADERS,
    body: JSON.stringify({ limit: 6000 }),
  })
  return (await resp.json()).items
}

async function updateWord(id, category, rank) {
  const res = await fetch(`${DB_URL}/api/v1/table/vocabulary/update`, {
    method: 'POST', headers: HEADERS,
    body: JSON.stringify({
      where: `id = '${id}'`,
      setValues: { category, rank },
    }),
  })
  return res.ok
}

async function batchRun(tasks, concurrency) {
  let ok = 0, fail = 0
  for (let i = 0; i < tasks.length; i += concurrency) {
    const results = await Promise.all(tasks.slice(i, i + concurrency).map(t => t()))
    ok   += results.filter(Boolean).length
    fail += results.filter(r => !r).length
    process.stdout.write(`\r  ${ok + fail}/${tasks.length} (✓${ok} ✗${fail})`)
  }
  console.log()
  return { ok, fail }
}

async function main() {
  const health = await fetch(`${DB_URL}/api/v1/health`).catch(() => null)
  if (!health?.ok) { console.error('✗ Backend not reachable'); process.exit(1) }

  // Загружаем words.json (уже с rank и новыми категориями)
  const bundleWords = JSON.parse(readFileSync(resolve(ROOT, 'Resources/words.json'), 'utf8'))
  const bundleMap = new Map(bundleWords.map(w => [w.polish, { category: w.category, rank: w.rank }]))
  console.log(`→ Bundle: ${bundleWords.length} words`)

  // Загружаем все слова из DB
  console.log('→ Fetching DB words...')
  const dbWords = await fetchAll()
  console.log(`  DB: ${dbWords.length} words`)

  // Матчим по polish и обновляем
  const tasks = []
  let noMatch = 0
  for (const dbWord of dbWords) {
    const bundle = bundleMap.get(dbWord.polish)
    if (!bundle) { noMatch++; continue }
    if (dbWord.category === bundle.category && dbWord.rank === bundle.rank) continue
    tasks.push(() => updateWord(dbWord.id, bundle.category, bundle.rank))
  }

  console.log(`\n→ Need to update: ${tasks.length} words (${noMatch} not in bundle, skipped)`)
  if (tasks.length === 0) { console.log('✓ Nothing to update'); return }

  const { ok, fail } = await batchRun(tasks, CONCURRENCY)
  console.log(`✓ Updated ${ok} words${fail > 0 ? `, ✗ ${fail} failed` : ''}`)

  // Финальная статистика
  const final = await fetchAll()
  const cats = {}
  for (const w of final) cats[w.category] = (cats[w.category] ?? 0) + 1
  const sorted = Object.entries(cats).sort(([a], [b]) => a.localeCompare(b, 'ru'))
  console.log(`\nDB categories (${sorted.length}):`)
  for (const [cat, cnt] of sorted) {
    console.log(`  ${cnt.toString().padStart(4)}  ${cat}`)
  }
}

main().catch(e => { console.error(e); process.exit(1) })
