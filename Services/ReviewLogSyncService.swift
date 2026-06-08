import Foundation
import SwiftData

/// Синхронизирует локальные ReviewLog'и (SwiftData) с бэкендом по cursor-методу:
/// шлёт всё, что `reviewDate > lastSyncedDate`, обновляет cursor после успешной отправки.
///
/// Идемпотентность: бэкенд имеет UNIQUE (user_id, card_id, review_date) — повторная
/// отправка того же лога вернёт ошибку, которую APIClient.insertReviewLog трактует как success.
///
/// Триггеры: `VerbumApp.scenePhase == .active`, `LearningEngine.processAnswer` после
/// завершения сессии.
@MainActor
final class ReviewLogSyncService {
    static let shared = ReviewLogSyncService()
    private init() {}

    private var isSyncing = false

    /// Fire-and-forget — не блокируем caller.
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

        // 1. Вытащить все логи новее cursor'а, отсортированные по времени.
        let descriptor = FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.reviewDate > lastSynced },
            sortBy: [SortDescriptor(\.reviewDate, order: .forward)]
        )
        guard let logs = try? context.fetch(descriptor), !logs.isEmpty else { return }

        // 2. Построить map cardId(local UUID) → remoteId(Teenybase UUID).
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

        // 3. Слать по одному; при первой ошибке — стоп, cursor НЕ продвигаем дальше точки сбоя.
        var lastSuccess = lastSynced
        var sent = 0, skipped = 0, failed = 0

        for log in logs {
            guard let remoteCardId = remoteMap[log.cardId] else {
                // Карточка без remoteId (offline bundle fallback) — пропускаем навсегда.
                // Cursor двигаем, чтобы не ретраить этот лог в следующий раз.
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
                print("⚠️ ReviewLogSync: failed at log \(log.cardId) @ \(log.reviewDate) — \(error)")
                break // следующий триггер продолжит с того же cursor'а
            }
        }

        if lastSuccess > lastSynced {
            UserDefaults.standard.set(lastSuccess, forKey: cursorKey)
        }
        if sent + skipped + failed > 0 {
            print("📤 ReviewLogSync: sent=\(sent), skipped=\(skipped), failed=\(failed)")
        }
    }
}
