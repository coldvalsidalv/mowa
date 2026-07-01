import {$Database, $Env, OpenApiExtension, PocketUIExtension, D1Adapter, teenyHono} from 'teenybase/worker'
import config from 'virtual:teenybase'
import {gradeWriting} from './writing'

type Env = $Env & {Bindings: CloudflareBindings}

const app = teenyHono<Env>(async (c) => {
    const db = new $Database(c, config, new D1Adapter(c.env.PRIMARY_DB))
    db.extensions.push(new OpenApiExtension(db, true))
    db.extensions.push(new PocketUIExtension(db))
    return db
})

// Phase 2: LLM grading of B1 writing tasks (custom route alongside Teenybase tables).
app.post('/api/v1/writing/grade', gradeWriting)

// TTS audio — serves pre-generated MP3 from R2; falls through to 404 if not generated yet.
app.get('/api/tts/:wordId', async (c) => {
    const wordId = c.req.param('wordId')
    const obj = await c.env.TTS_BUCKET.get(`${wordId}.mp3`)
    if (!obj) return c.notFound()
    return new Response(obj.body, {
        headers: {
            'Content-Type': 'audio/mpeg',
            'Cache-Control': 'public, max-age=31536000, immutable',
        },
    })
})

// TTS upload — admin-only, used by generate-tts.mjs.
app.put('/api/admin/tts/:wordId', async (c) => {
    const token = c.req.header('Authorization')?.replace('Bearer ', '')
    if (!token || token !== c.env.ADMIN_SERVICE_TOKEN) {
        return c.json({ error: 'Unauthorized' }, 401)
    }
    const wordId = c.req.param('wordId')
    const body = await c.req.arrayBuffer()
    await c.env.TTS_BUCKET.put(`${wordId}.mp3`, body, {
        httpMetadata: { contentType: 'audio/mpeg' },
    })
    return c.json({ ok: true })
})

export default app
