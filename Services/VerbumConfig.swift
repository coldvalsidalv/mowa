import Foundation

enum VerbumConfig {
    /// Базовый URL бэкенда. Меняем только здесь при деплое в прод.
    #if DEBUG
    static let baseURL = "http://127.0.0.1:8787"
    #else
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
