/**
 * generate-tts.mjs — генерирует MP3 для всех слов словаря через ElevenLabs и кладёт в R2.
 * Ключ в R2: URL-энкодинг польского слова (не зависит от remoteId/DB).
 *
 * Настройка:
 *   1. Получи API-ключ на elevenlabs.io → Profile → API Keys
 *   2. Выбери голос: elevenlabs.io/voice-lab → скопируй Voice ID
 *      Рекомендации для польского: Agnieszka, Zofia, или любой multilingual голос
 *   3. Задай переменные:
 *        export ELEVENLABS_API_KEY=sk_...
 *        export ELEVENLABS_VOICE_ID=<voice_id>
 *        export VERBUM_ADMIN_TOKEN=<токен из backend/.dev.vars или prod-секрет>
 *        export VERBUM_BACKEND_URL=https://verbum-backend.verbum-mowa.workers.dev
 *
 * Запуск (из корня репо): node backend/scripts/generate-tts.mjs
 *
 * Скрипт пропускает слова, для которых аудио уже есть в R2.
 */

import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '../..')

const ELEVENLABS_API_KEY  = process.env.ELEVENLABS_API_KEY
const ELEVENLABS_VOICE_ID = process.env.ELEVENLABS_VOICE_ID
const ADMIN_TOKEN         = process.env.VERBUM_ADMIN_TOKEN
const BACKEND_URL         = process.env.VERBUM_BACKEND_URL ?? 'http://127.0.0.1:8787'

const ELEVENLABS_MODEL    = 'eleven_turbo_v2_5'
const OUTPUT_FORMAT       = 'mp3_44100_64'
const CONCURRENCY         = 3   // параллельных запросов к ElevenLabs
const DELAY_MS            = 300 // задержка между батчами (мс)

if (!ELEVENLABS_API_KEY || !ELEVENLABS_VOICE_ID || !ADMIN_TOKEN) {
  console.error('✗ Задай переменные: ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID, VERBUM_ADMIN_TOKEN')
  process.exit(1)
}

// ─── Load vocabulary from bundle ──────────────────────────────────────────────

function loadWords() {
  const raw = JSON.parse(readFileSync(resolve(ROOT, 'Resources/words.json'), 'utf8'))
  // Дедупликация по polish: омонимы дают одинаковый звук, дублировать не нужно.
  const seen = new Set()
  return raw.filter(w => {
    if (seen.has(w.polish)) return false
    seen.add(w.polish)
    return true
  })
}

// ─── ElevenLabs TTS ───────────────────────────────────────────────────────────

async function generateAudio(text) {
  const res = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}?output_format=${OUTPUT_FORMAT}`,
    {
      method: 'POST',
      headers: {
        'xi-api-key': ELEVENLABS_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text,
        model_id: ELEVENLABS_MODEL,
        language_code: 'pl',
        voice_settings: { stability: 0.5, similarity_boost: 0.8, style: 0.0, use_speaker_boost: true },
      }),
    }
  )
  if (res.status === 429) throw new Error('rate_limit')
  if (!res.ok) throw new Error(`ElevenLabs error: ${res.status} ${await res.text()}`)
  return Buffer.from(await res.arrayBuffer())
}

// ─── Upload to R2 via backend ─────────────────────────────────────────────────

async function uploadAudio(polishWord, audioBuffer) {
  const key = encodeURIComponent(polishWord)
  const res = await fetch(`${BACKEND_URL}/api/admin/tts/${key}`, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${ADMIN_TOKEN}`,
      'Content-Type': 'audio/mpeg',
    },
    body: audioBuffer,
  })
  if (!res.ok) throw new Error(`Upload failed for "${polishWord}": ${res.status}`)
}

async function audioExists(polishWord) {
  const key = encodeURIComponent(polishWord)
  const res = await fetch(`${BACKEND_URL}/api/tts/${key}`, { method: 'HEAD' })
  return res.ok
}

// ─── Main ─────────────────────────────────────────────────────────────────────

const FORCE = process.env.FORCE === '1'

async function processWord(word) {
  if (!FORCE && await audioExists(word.polish)) return 'skip'
  const audio = await generateAudio(word.polish)
  await uploadAudio(word.polish, audio)
  return 'ok'
}

async function runBatch(words) {
  return Promise.allSettled(words.map(w => processWord(w)))
}

async function main() {
  console.log(`→ Connecting to ${BACKEND_URL}...`)
  const health = await fetch(`${BACKEND_URL}/api/v1/health`).catch(() => null)
  if (!health?.ok) {
    console.error('✗ Backend not reachable')
    process.exit(1)
  }

  const words = loadWords()
  console.log(`→ Loaded ${words.length} unique words from bundle\n`)

  let ok = 0, skipped = 0, failed = 0

  for (let i = 0; i < words.length; i += CONCURRENCY) {
    const batch = words.slice(i, i + CONCURRENCY)
    const results = await runBatch(batch)

    const rateLimited = []
    for (let j = 0; j < results.length; j++) {
      const r = results[j]
      if (r.status === 'fulfilled') {
        if (r.value === 'skip') skipped++
        else ok++
      } else {
        const err = r.reason?.message ?? r.reason
        if (err === 'rate_limit') {
          rateLimited.push(batch[j])
        } else {
          console.error(`  ✗ ${batch[j].polish}: ${err}`)
          failed++
        }
      }
    }
    if (rateLimited.length > 0) {
      console.log(`\n  Rate limit (${rateLimited.length}) — ждём 60с...`)
      await new Promise(res => setTimeout(res, 60_000))
      const retryResults = await Promise.allSettled(rateLimited.map(w => processWord(w)))
      for (let k = 0; k < retryResults.length; k++) {
        const r = retryResults[k]
        if (r.status === 'fulfilled') {
          if (r.value === 'skip') skipped++
          else ok++
        } else {
          const retryErr = r.reason?.message ?? r.reason
          console.error(`  ✗ ${rateLimited[k].polish} (${rateLimited[k].id}): ${retryErr}`)
          failed++
        }
      }
    }

    process.stdout.write(`\r  ${i + batch.length}/${words.length} (✓${ok} ⏭${skipped} ✗${failed})`)
    if (DELAY_MS > 0) await new Promise(res => setTimeout(res, DELAY_MS))
  }

  console.log(`\n\n✓ Done: generated=${ok}, skipped=${skipped}, failed=${failed}`)
}

main().catch(e => { console.error(e); process.exit(1) })
