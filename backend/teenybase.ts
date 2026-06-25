import { DatabaseSettings, TableAuthExtensionData, TableRulesExtensionData, sql } from 'teenybase'
import { baseFields, authFields, createdTrigger, updatedTrigger } from 'teenybase/scaffolds/fields'

export default {
  appUrl: 'http://localhost:8787',
  jwtSecret: '$JWT_SECRET',

  tables: [
    // ─── USERS ───────────────────────────────────────────────────────────────
    {
      name: 'users',
      autoSetUid: true,
      fields: [...baseFields, ...authFields],
      triggers: [createdTrigger, updatedTrigger],
      extensions: [
        {
          name: 'auth',
          jwtSecret: '$JWT_SECRET_USERS',
          jwtTokenDuration: 10800,
          maxTokenRefresh: 5,
        } as TableAuthExtensionData,
        {
          name: 'rules',
          createRule: 'true',
          viewRule: 'auth.uid == id',
          updateRule: 'auth.uid == id',
          deleteRule: 'auth.uid == id',
        } as TableRulesExtensionData,
      ],
    },

    // ─── VOCABULARY ──────────────────────────────────────────────────────────
    {
      name: 'vocabulary',
      autoSetUid: true,
      fields: [
        ...baseFields,
        { name: 'polish',       type: 'text', sqlType: 'text', notNull: true },
        { name: 'translation',  type: 'text', sqlType: 'text', notNull: true },
        { name: 'transcription',type: 'text', sqlType: 'text' },
        { name: 'part_of_speech', type: 'text', sqlType: 'text' },
        { name: 'example',      type: 'text', sqlType: 'text' },
        { name: 'examples_list',type: 'json', sqlType: 'json' },
        { name: 'category',     type: 'text', sqlType: 'text', notNull: true },
        { name: 'level',        type: 'text', sqlType: 'text' },
        { name: 'image_name',   type: 'text', sqlType: 'text' },
        { name: 'rank',         type: 'number', sqlType: 'integer', default: { q: '0' } },
        { name: 'inflections',  type: 'json',   sqlType: 'json' },
      ],
      triggers: [createdTrigger, updatedTrigger],
      extensions: [
        {
          name: 'rules',
          // Чтение публичное — приложение тянет без авторизации
          listRule: 'true',
          viewRule: 'true',
          // Запись только администратор
          createRule: 'auth.role == "admin"',
          updateRule: 'auth.role == "admin"',
          deleteRule: 'auth.role == "admin"',
        } as TableRulesExtensionData,
      ],
    },

    // ─── REVIEW LOGS ─────────────────────────────────────────────────────────
    // Иммутабельные записи каждого ответа в SRS-сессии. Источник данных
    // для будущего FSRS-оптимизатора (Фаза 3b). По одному ряду на review,
    // дедупликация через unique (user_id, card_id, review_date).
    {
      name: 'review_logs',
      autoSetUid: true,
      fields: [
        ...baseFields,
        { name: 'user_id', type: 'relation', sqlType: 'text', notNull: true,
          foreignKey: { table: 'users', column: 'id' } },
        // card_id — Teenybase UUID карточки из vocabulary, НЕ локальный SwiftData id.
        // Клиент пропускает логи карточек без remoteId (offline-fallback bundle).
        { name: 'card_id', type: 'text', sqlType: 'text', notNull: true },
        // 1=Again, 2=Hard, 3=Good, 4=Easy (FSRSRating).
        { name: 'rating', type: 'integer', sqlType: 'integer', notNull: true,
          check: sql`rating IN (1, 2, 3, 4)` },
        // UTC datetime ответа.
        { name: 'review_date', type: 'date', sqlType: 'datetime', notNull: true },
        // Сколько мс юзер думал перед ответом — для аналитики.
        { name: 'review_duration_ms', type: 'integer', sqlType: 'integer', default: { q: '0' } },
      ],
      // Только createdTrigger — логи иммутабельны, поле updated не нужно.
      triggers: [createdTrigger],
      indexes: [
        // Идемпотентность повторных синков: один и тот же ответ нельзя записать дважды.
        { name: 'review_logs_user_card_date_unique',
          fields: ['user_id', 'card_id', 'review_date'], unique: true },
        // Хронологический скан логов юзера — нужен оптимизатору.
        { name: 'review_logs_user_date',
          fields: ['user_id', 'review_date'] },
      ],
      extensions: [
        {
          name: 'rules',
          listRule: 'auth.uid == user_id',
          viewRule: 'auth.uid == user_id',
          // Клиент обязан слать user_id == свой auth.uid.
          createRule: 'auth.uid != null & new.user_id == auth.uid',
          updateRule: 'false',   // иммутабельны
          deleteRule: 'false',
        } as TableRulesExtensionData,
      ],
    },

    // ─── FSRS PARAMS ─────────────────────────────────────────────────────────
    // Персональные веса FSRS-6 для конкретного юзера. Заполняются периодически
    // оптимизатором (Фаза 3b) по накопленным review_logs. Один ряд на юзера.
    // Клиент тянет на старте; nil/missing → использует дефолты v6.
    {
      name: 'fsrs_params',
      autoSetUid: true,
      fields: [
        ...baseFields,
        { name: 'user_id', type: 'relation', sqlType: 'text', notNull: true, unique: true,
          foreignKey: { table: 'users', column: 'id' } },
        // 21 double — FSRS-6 веса. Валидируем shape на клиенте.
        { name: 'parameters', type: 'json', sqlType: 'json', notNull: true,
          check: sql`json_valid(parameters)` },
        // 0.80–0.95. На бэке не клампим — клиент знает свои пределы.
        { name: 'desired_retention', type: 'number', sqlType: 'real', notNull: true },
        // [секунд, ...] — learning steps. Дефолт клиента [60, 600].
        { name: 'learning_steps', type: 'json', sqlType: 'json', notNull: true,
          check: sql`json_valid(learning_steps)` },
        // [секунд, ...] — relearning steps. Дефолт клиента [600].
        { name: 'relearning_steps', type: 'json', sqlType: 'json', notNull: true,
          check: sql`json_valid(relearning_steps)` },
      ],
      triggers: [createdTrigger, updatedTrigger],
      extensions: [
        {
          name: 'rules',
          // Чтение — только своего.
          listRule: 'auth.uid == user_id',
          viewRule: 'auth.uid == user_id',
          // Запись — только admin / optimizer service (через ADMIN_SERVICE_TOKEN).
          // Юзер не может править свои веса сам — иначе оптимизация теряет смысл.
          createRule: 'auth.role == "admin"',
          updateRule: 'auth.role == "admin"',
          deleteRule: 'auth.role == "admin"',
        } as TableRulesExtensionData,
      ],
    },

    // ─── GRAMMAR LESSONS ─────────────────────────────────────────────────────
    {
      name: 'grammar_lessons',
      autoSetUid: true,
      fields: [
        ...baseFields,
        { name: 'lesson_id',    type: 'text', sqlType: 'text', notNull: true },
        { name: 'title',        type: 'text', sqlType: 'text', notNull: true },
        { name: 'description',  type: 'text', sqlType: 'text' },
        { name: 'level',        type: 'text', sqlType: 'text', notNull: true },
        { name: 'order_index',  type: 'number', sqlType: 'integer', default: { q: '0' } },
        // Шаги хранятся как JSON-массив — нет смысла нормализовывать для MVP
        { name: 'steps',        type: 'json', sqlType: 'json', notNull: true },
      ],
      triggers: [createdTrigger, updatedTrigger],
      extensions: [
        {
          name: 'rules',
          listRule: 'true',
          viewRule: 'true',
          createRule: 'auth.role == "admin"',
          updateRule: 'auth.role == "admin"',
          deleteRule: 'auth.role == "admin"',
        } as TableRulesExtensionData,
      ],
    },

    // ─── EXAM SESSIONS ───────────────────────────────────────────────────────
    // Официальные даты госэкзамена. Обновляются вручную раз в год (API у
    // Państwowa Komisja нет). Клиент тянет по /list, фоллбэк — bundle JSON.
    {
      name: 'exam_sessions',
      autoSetUid: true,
      fields: [
        ...baseFields,
        { name: 'session_id', type: 'text', sqlType: 'text', notNull: true },
        { name: 'start_date', type: 'text', sqlType: 'text', notNull: true },
        { name: 'end_date',   type: 'text', sqlType: 'text', notNull: true },
        // Уровни для взрослых на сессии, JSON-массив: ["B1","B2"]
        { name: 'levels',     type: 'json', sqlType: 'json', notNull: true },
      ],
      triggers: [createdTrigger, updatedTrigger],
      extensions: [
        {
          name: 'rules',
          listRule: 'true',
          viewRule: 'true',
          createRule: 'auth.role == "admin"',
          updateRule: 'auth.role == "admin"',
          deleteRule: 'auth.role == "admin"',
        } as TableRulesExtensionData,
      ],
    },

    // ─── WRITING ATTEMPTS ────────────────────────────────────────────────────
    // One row per graded essay. Serves the per-user daily rate limit (budget
    // guard for the paid LLM endpoint) and doubles as server-side history.
    // Written by the worker via raw D1; clients don't read it directly.
    {
      name: 'writing_attempts',
      autoSetUid: true,
      fields: [
        ...baseFields,
        { name: 'user_id',         type: 'text', sqlType: 'text', notNull: true },
        { name: 'task_id',         type: 'text', sqlType: 'text', notNull: true },
        { name: 'overall_percent', type: 'number', sqlType: 'integer', default: { q: '0' } },
        { name: 'passed',          type: 'number', sqlType: 'integer', default: { q: '0' } },
      ],
      triggers: [createdTrigger, updatedTrigger],
      extensions: [
        {
          name: 'rules',
          listRule: 'auth.role == "admin"',
          viewRule: 'auth.role == "admin"',
          createRule: 'auth.role == "admin"',
          updateRule: 'auth.role == "admin"',
          deleteRule: 'auth.role == "admin"',
        } as TableRulesExtensionData,
      ],
    },
  ],
} satisfies DatabaseSettings
