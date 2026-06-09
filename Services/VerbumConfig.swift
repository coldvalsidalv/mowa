import Foundation

enum VerbumConfig {
    /// Базовый URL бэкенда. Меняем только здесь при деплое в прод.
    #if DEBUG
    // На симуляторе работает 127.0.0.1 (loopback на Mac).
    // Для теста на физическом девайсе: подними cloudflared/ngrok туннель и
    // временно подставь https URL во вторую строку. НЕ коммить tunnel URL —
    // он ephemeral. См. CLAUDE.md → "Тестирование на физическом девайсе".
    static let baseURL = "http://127.0.0.1:8787"
    // static let baseURL = "https://<your-tunnel>.trycloudflare.com"
    #else
    #warning("Release build: подставь реальный прод-URL бэкенда вместо placeholder")
    static let baseURL = "https://verbum-backend.YOUR_ACCOUNT.workers.dev"
    #endif

    /// Публичный токен для чтения контента (vocabulary, grammar).
    /// Не является секретом — контент публично доступен по правилам Teenybase.
    static let contentReadToken = ""

    // MARK: - FSRS

    /// Целевой уровень удержания (0.80–0.95). Чем выше, тем чаще повторения.
    /// 0.90 — общепринятый baseline (Anki/RemNote).
    static let fsrsDesiredRetention: Double = 0.90

    /// stability ≥ этого значения (дней) → разблокируем cloze-режим.
    static let fsrsClozeUnlockStability: Double = 7.0

    /// Максимум повторений одной карточки за сессию при ответе .again.
    /// Предотвращает бесконечную сессию в плохой день.
    static let fsrsMaxAgainRepeatsPerSession: Int = 3
}
