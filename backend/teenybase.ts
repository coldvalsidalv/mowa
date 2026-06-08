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
