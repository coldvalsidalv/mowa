import Foundation

// MARK: - Review Logs

extension APIClient {
    /// Загружает один ReviewLog на бэкенд. Идемпотентно — при коллизии
    /// (user_id, card_id, review_date) сервер вернёт 4xx, мы трактуем это как success.
    /// `cardId` — Teenybase UUID карточки (remoteId), не локальный SwiftData UUID.
    func insertReviewLog(userId: String,
                         cardId: String,
                         rating: Int,
                         reviewDate: Date,
                         reviewDurationMs: Int) async throws {
        let body: [String: Any] = [
            "values": [
                "user_id": userId,
                "card_id": cardId,
                "rating": rating,
                "review_date": ISO8601DateFormatter.teenybase.string(from: reviewDate),
                "review_duration_ms": reviewDurationMs
            ]
        ]
        do {
            let _: TeenyEmpty = try await post(path: "/api/v1/table/review_logs/insert", body: body)
        } catch APIError.serverError(let code, let message)
            where code == 409 || (code == 400 && message?.localizedCaseInsensitiveContains("unique") == true) {
            // Unique constraint (user_id, card_id, review_date) — повторный синк того же
            // лога, трактуем как success. Любые другие ошибки (401, валидация и т.д.)
            // пробрасываем: caller не должен продвигать cursor, иначе лог потерян навсегда.
        }
    }
}
