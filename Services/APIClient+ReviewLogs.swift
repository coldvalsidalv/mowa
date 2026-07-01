import Foundation

// MARK: - Review Logs

extension APIClient {
    /// Uploads a single ReviewLog to the backend. Idempotent — on a collision
    /// (user_id, card_id, review_date) the server returns 4xx, which we treat as success.
    /// `cardId` is the Teenybase card UUID (remoteId), not the local SwiftData UUID.
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
            // Unique constraint (user_id, card_id, review_date) — re-syncing the same
            // log, treated as success. Any other error (401, validation, etc.) is
            // rethrown: the caller must not advance the cursor, or the log is lost forever.
        }
    }
}
