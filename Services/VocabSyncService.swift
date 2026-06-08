import Foundation
import SwiftData

/// Синхронизирует словарь из Teenybase в локальный SwiftData.
/// Первый запуск: полная загрузка. Последующие: delta по updated timestamp.
@MainActor
final class VocabSyncService {
    static let shared = VocabSyncService()
    private init() {}

    private let lastSyncKey = "vocabLastSyncedAt"

    // MARK: - Public

    func syncIfNeeded(context: ModelContext) {
        Task { await sync(context: context) }
    }

    // MARK: - Internal

    private func sync(context: ModelContext) async {
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        let isFirstSync = lastSync == nil
        let syncStarted = Date()

        do {
            let words: [RemoteWord]
            if let since = lastSync {
                words = try await APIClient.shared.fetchWordsDelta(since: since)
                guard !words.isEmpty else { return }
                print("🔄 VocabSyncService: delta sync — \(words.count) updated words")
            } else {
                words = try await APIClient.shared.fetchAllWords()
                guard !words.isEmpty else {
                    fallbackToBundle(context: context)
                    return
                }
                print("📥 VocabSyncService: full sync — \(words.count) words")
            }

            try upsert(words: words, isFirstSync: isFirstSync, context: context)
            UserDefaults.standard.set(syncStarted, forKey: lastSyncKey)
        } catch {
            print("⚠️ VocabSyncService: API unavailable — \(error)")
            if isFirstSync { fallbackToBundle(context: context) }
        }
    }

    private func upsert(words: [RemoteWord], isFirstSync: Bool, context: ModelContext) throws {
        let allItems = try context.fetch(FetchDescriptor<VocabItem>())
        let existing = Dictionary(uniqueKeysWithValues: allItems.compactMap { item in
            item.remoteId.map { ($0, item) }
        })

        var inserted = 0, updated = 0
        for word in words {
            if let item = existing[word.id] {
                item.apply(word)
                updated += 1
            } else {
                context.insert(VocabItem(remote: word))
                inserted += 1
            }
        }

        if isFirstSync {
            let stale = allItems.filter { $0.remoteId == nil }
            stale.forEach { context.delete($0) }
            if !stale.isEmpty {
                print("🗑️ VocabSyncService: removed \(stale.count) stale bundle items")
            }
        }

        try context.save()
        print("✅ VocabSyncService: inserted \(inserted), updated \(updated)")

        // Сигналим UI пересчитать категории. LessonsView убрал @Query
        // ради перфа на main thread, поэтому live-обновление теперь через notification.
        if inserted > 0 || updated > 0 {
            NotificationCenter.default.post(name: .vocabularyDidChange, object: nil)
        }
    }

    private func fallbackToBundle(context: ModelContext) {
        let words = DataManager.shared.loadWordsFromBundle()
        guard !words.isEmpty else {
            print("❌ VocabSyncService: bundle is empty")
            return
        }
        for word in words {
            context.insert(VocabItem(bundle: word))
        }
        try? context.save()
        print("📦 VocabSyncService: seeded \(words.count) words from bundle (offline fallback)")
    }
}

// MARK: - VocabItem mapping

private extension VocabItem {
    convenience init(remote: RemoteWord) {
        self.init(
            polish: remote.polish,
            translation: remote.translation,
            partOfSpeech: remote.part_of_speech ?? "",
            example: remote.example ?? "",
            category: remote.category,
            rank: remote.rank ?? 0,
            inflections: remote.inflections ?? "{}",
            remoteId: remote.id
        )
    }

    convenience init(bundle: BundleWord) {
        let inflJson = (try? JSONSerialization.data(withJSONObject: bundle.inflections))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.init(
            polish: bundle.polish,
            translation: bundle.translation,
            partOfSpeech: bundle.partOfSpeech,
            example: bundle.example,
            category: bundle.category,
            rank: bundle.rank,
            inflections: inflJson
        )
    }

    func apply(_ word: RemoteWord) {
        polish = word.polish
        translation = word.translation
        partOfSpeech = word.part_of_speech ?? partOfSpeech
        example = word.example ?? example
        category = word.category
        rank = word.rank ?? rank
        inflections = word.inflections ?? inflections
    }
}

extension Notification.Name {
    /// Постится после успешного VocabSyncService.upsert (когда что-то изменилось).
    /// LessonsView подписан и перезагружает категории.
    static let vocabularyDidChange = Notification.Name("vocabularyDidChange")
}
