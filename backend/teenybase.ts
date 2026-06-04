import { DatabaseSettings, TableAuthExtensionData, TableRulesExtensionData } from 'teenybase'
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
  ],
} satisfies DatabaseSettings
