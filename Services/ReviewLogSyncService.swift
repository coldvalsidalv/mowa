import Foundation
import SwiftData

/// Syncs local ReviewLogs (SwiftData) to the backend via a cursor method:
/// sends everything with `reviewDate > lastSyncedDate` and advances the cursor after a successful send.
///
/// Idempotency: the backend has UNIQUE (user_id, card_id, review_date) — re-sending
/// the same log returns an error, which APIClient.insertReviewLog treats as success.
///
/// Triggers: `VerbumApp.scenePhase == .active`, `LearningEngine.processAnswer` after
/// a session ends.
@MainActor
final class ReviewLogSyncService {
    static let shared = ReviewLogSyncService()
    private init() {}

    private var isSyncing = false

    /// Fire-and-forget — don't block the caller.
    func syncIfNeeded(context: ModelContext) {
        Task { await sync(context: context) }
    }

    // MARK: - Private

    private func sync(context: ModelContext) async {
        guard !isSyncing else { return }
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else { return }
        isSyncing = true
        defer { isSyncing = false }

        let cursorKey = "reviewLogSyncCursor_\(userId)"
        let lastSynced = (UserDefaults.standard.object(forKey: cursorKey) as? Date) ?? .distantPast

        // 1. Fetch the current user's logs newer than the cursor, sorted by time.
        // Filtering by userId is required: after switching accounts the new user's cursor
        // = distantPast, and without the filter the whole previous user's history would go under the wrong user_id.
        let descriptor = FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.reviewDate > lastSynced && $0.userId == userId },
            sortBy: [SortDescriptor(\.reviewDate, order: .forward)]
        )
        guard let logs = try? context.fetch(descriptor), !logs.isEmpty else { return }

        // 2. Build a map cardId(local UUID) → remoteId(Teenybase UUID).
        // Fetching only the cards referenced in this batch (typically 10-50), not all 5000.
        let batchCardIds = Set(logs.map { $0.cardId })
        var remoteMap: [UUID: String] = [:]
        for cardId in batchCardIds {
            let id = cardId
            let desc = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.id == id })
            if let item = (try? context.fetch(desc))?.first, let remoteId = item.remoteId {
                remoteMap[cardId] = remoteId
            }
        }

        // 3. Send one at a time; on the first error — stop, do NOT advance the cursor past the failure point.
        var lastSuccess = lastSynced
        var sent = 0, skipped = 0, failed = 0

        for log in logs {
            guard let remoteCardId = remoteMap[log.cardId] else {
                // Card without a remoteId (offline bundle fallback) — skip it forever.
                // Advance the cursor so we don't retry this log next time.
                skipped += 1
                if log.reviewDate > lastSuccess { lastSuccess = log.reviewDate }
                continue
            }
            do {
                try await APIClient.shared.insertReviewLog(
                    userId: userId,
                    cardId: remoteCardId,
                    rating: log.rating.rawValue,
                    reviewDate: log.reviewDate,
                    reviewDurationMs: log.reviewDurationMs
                )
                sent += 1
                if log.reviewDate > lastSuccess { lastSuccess = log.reviewDate }
            } catch {
                failed += 1
                verbumLog("⚠️ ReviewLogSync: failed at log \(log.cardId) @ \(log.reviewDate) — \(error)")
                break // the next trigger continues from the same cursor
            }
        }

        if lastSuccess > lastSynced {
            UserDefaults.standard.set(lastSuccess, forKey: cursorKey)
        }
        if sent + skipped + failed > 0 {
            verbumLog("📤 ReviewLogSync: sent=\(sent), skipped=\(skipped), failed=\(failed)")
        }
    }
}
