/**
 * remap_categories.mjs — консолидирует дублирующиеся категории словаря
 * Запуск: node backend/scripts/remap_categories.mjs
 */

const DB_URL = 'http://127.0.0.1:8787'
const TOKEN  = 'verbum-local-admin-token-change-in-prod'
const HEADERS = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${TOKEN}`,
}

const REMAP = {
  'Jedzenie':         'Еда и напитки',
  'Dom':              'Дом и быт',
  'Ciało':            'Тело и здоровье',
  'Czas':             'Время и календарь',
  'Rodzina i Ludzie': 'Семья и люди',
  'Liczby':           'Числа и количество',
  'Natura':           'Природа и погода',
  'Kolory':           'Цвета и формы',
  'Czynności':        'Повседневные глаголы',
  'Miasto':           'Город и места',
  'Inne':             'Разное',
  'Przymiotniki':     'Прилагательные',
  'Pytania':          'Служебные слова',
  'Przyimki/Zaimki':  'Служебные слова',
  'Gramatyka':        'Служебные слова',
  'Еда':              'Еда и напитки',
  'Дом':              'Дом и быт',
  'Тело':             'Тело и здоровье',
  'Здоровье':         'Тело и здоровье',
  'Время':            'Время и календарь',
  'Дни недели':       'Время и календарь',
  'Месяцы':           'Время и календарь',
  'Времена года':     'Время и календарь',
  'Семья':            'Семья и люди',
  'Люди':             'Семья и люди',
  'Числа':            'Числа и количество',
  'Природа':          'Природа и погода',
  'Погода':           'Природа и погода',
  'Цвета':            'Цвета и формы',
  'Действия':         'Повседневные глаголы',
  'Глаголы':          'Повседневные глаголы',
  'Город':            'Город и места',
  'Места':            'Город и места',
  'Транспорт':        'Транспорт и путешествия',
  'Путешествия':      'Транспорт и путешествия',
  'Одежда':           'Одежда и мода',
  'Профессии':        'Работа и профессии',
  'Школа':            'Образование',
  'Школа/Офис':       'Образование',
  'Чувства':          'Эмоции и чувства',
  'Абстрактное':      'Разное',
  'Вещи':             'Разное',
}

async function fetchAll() {
  const resp = await fetch(`${DB_URL}/api/v1/table/vocabulary/list`, {
    method: 'POST', headers: HEADERS,
    body: JSON.stringify({ limit: 6000 }),
  })
  const d = await resp.json()
  return d.items
}

async function updateByIds(ids, category, concurrency = 30) {
  let total = 0
  for (let i = 0; i < ids.length; i += concurrency) {
    const chunk = ids.slice(i, i + concurrency)
    const results = await Promise.all(chunk.map(id =>
      fetch(`${DB_URL}/api/v1/table/vocabulary/update`, {
        method: 'POST', headers: HEADERS,
        body: JSON.stringify({ where: `id = '${id}'`, setValues: { category } }),
      }).then(r => r.ok ? 1 : 0)
    ))
    total += results.reduce((a, b) => a + b, 0)
  }
  return total
}

async function main() {
  const health = await fetch(`${DB_URL}/api/v1/health`).catch(() => null)
  if (!health?.ok) {
    console.error('✗ Backend not reachable — run: npm run dev')
    process.exit(1)
  }

  console.log('→ Fetching all words...')
  const words = await fetchAll()
  console.log(`  ${words.length} words loaded\n`)

  // Группируем ID по категориям требующим замены
  const byCategory = {}
  for (const w of words) {
    if (REMAP[w.category]) {
      const target = REMAP[w.category]
      if (!byCategory[w.category]) byCategory[w.category] = { ids: [], target }
      byCategory[w.category].ids.push(w.id)
    }
  }

  let totalUpdated = 0
  for (const [from, { ids, target }] of Object.entries(byCategory)) {
    const count = await updateByIds(ids, target)
    console.log(`  ${count.toString().padStart(4)}  "${from}" → "${target}"`)
    totalUpdated += count
  }

  console.log(`\n✓ Updated ${totalUpdated} words`)

  // Финальный список
  const final = await fetchAll()
  const cats = {}
  for (const w of final) cats[w.category] = (cats[w.category] ?? 0) + 1
  console.log(`\nФинальные категории (${Object.keys(cats).length}):`)
  for (const [cat, cnt] of Object.entries(cats).sort()) {
    console.log(`  ${cnt.toString().padStart(4)}  ${cat}`)
  }
}

main().catch(e => { console.error(e); process.exit(1) })
