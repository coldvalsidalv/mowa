/**
 * seed_exam_sessions.mjs — загружает официальные даты госэкзамена в Teenybase.
 * Источник истины — Resources/exam_sessions.json (он же bundle-фоллбэк).
 * Запуск: node backend/scripts/seed_exam_sessions.mjs
 *
 * Обновление дат на новый год: правишь Resources/exam_sessions.json,
 * затем прогоняешь этот скрипт (он upsert'ит по session_id).
 */

import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '../..')

const DB_URL = 'http://localhost:8787'
const TOKEN = 'verbum-local-admin-token-change-in-prod'

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${TOKEN}`,
}

async function list() {
  const res = await fetch(`${DB_URL}/api/v1/table/exam_sessions/list`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ limit: 100 }),
  })
  if (!res.ok) return []
  const json = await res.json()
  return json.items ?? []
}

async function insert(values) {
  const res = await fetch(`${DB_URL}/api/v1/table/exam_sessions/insert`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ values, returning: 'id' }),
  })
  return res.ok ? 'inserted' : `FAILED: ${await res.text()}`
}

async function update(id, values) {
  const res = await fetch(`${DB_URL}/api/v1/table/exam_sessions/update`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ where: `id == "${id}"`, setValues: values }),
  })
  return res.ok ? 'updated' : `FAILED: ${await res.text()}`
}

const sessions = JSON.parse(
  readFileSync(resolve(ROOT, 'Resources/exam_sessions.json'), 'utf8')
)

const existing = await list()
const byKey = new Map(existing.map((s) => [s.session_id, s.id]))

for (const s of sessions) {
  // json-поле levels Teenybase принимает строкой, не массивом.
  const values = {
    session_id: s.session_id,
    start_date: s.start_date,
    end_date: s.end_date,
    levels: JSON.stringify(s.levels),
  }
  const id = byKey.get(s.session_id)
  const result = id ? await update(id, values) : await insert(values)
  console.log(s.session_id, '->', result)
}
