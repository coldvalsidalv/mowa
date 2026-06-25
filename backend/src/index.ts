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

export default app
