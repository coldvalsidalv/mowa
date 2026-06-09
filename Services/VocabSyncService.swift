import Foundation
import SwiftData

/// Синхронизирует словарь из Teenybase в локальный SwiftData.
/// Первый запуск: полная загрузка. Последующие: delta по updated timestamp.
@MainActor
final class VocabSyncService {
    static let shared = VocabSyncService()
    private init() {}

    private let lastSyncKey = "vocabLastSyncedAt"
    private var isSyncing = false

    // MARK: - Public

    func syncIfNeeded(context: ModelContext) {
        Task { await sync(context: context) }
    }

    // MARK: - Internal

    private func sync(context: ModelContext) async {
        // HomeView.onAppear дёргает sync на каждое переключение таба —
        // без guard'а конкурентные full sync вставляют дубликаты.
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

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
        var inserted = 0, updated = 0

        if isFirstSync {
            // First sync: load all existing items once to handle stale bundle entries.
            let allItems = try context.fetch(FetchDescriptor<VocabItem>())
            let existing = Dictionary(uniqueKeysWithValues: allItems.compactMap { item in
                item.remoteId.map { ($0, item) }
            })

            // Bundle-слова (remoteId == nil) матчим по polish, чтобы не потерять
            // fsrsData-прогресс юзера, начавшего offline. Неоднозначные polish
            // (омонимы) не матчим — пойдут через insert/delete.
            let bundleItems = allItems.filter { $0.remoteId == nil }
            var byPolish: [String: VocabItem] = [:]
            for (polish, group) in Dictionary(grouping: bundleItems, by: \.polish) where group.count == 1 {
                byPolish[polish] = group[0]
            }

            for word in words {
                if let item = existing[word.id] {
                    item.apply(word)
                    updated += 1
                } else if let item = byPolish.removeValue(forKey: word.polish) {
                    item.remoteId = word.id
                    item.apply(word)
                    updated += 1
                } else {
                    context.insert(VocabItem(remote: word))
                    inserted += 1
                }
            }
            // Adopted items получили remoteId выше и сюда не попадают.
            let stale = allItems.filter { $0.remoteId == nil }
            stale.forEach { context.delete($0) }
            if !stale.isEmpty {
                print("🗑️ VocabSyncService: removed \(stale.count) stale bundle items")
            }
        } else {
            // Delta sync: words is a small changed set — look up each one individually.
            for word in words {
                let remoteId = word.id
                let desc = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.remoteId == remoteId })
                if let item = (try? context.fetch(desc))?.first {
                    item.apply(word)
                    updated += 1
                } else {
                    context.insert(VocabItem(remote: word))
                    inserted += 1
                }
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
        // Seed только в пустую базу: sync вызывается на каждый onAppear HomeView,
        // и без этой проверки каждый offline-вызов вставлял бы бандл заново.
        let existingCount = (try? context.fetchCount(FetchDescriptor<VocabItem>())) ?? 0
        guard existingCount == 0 else { return }

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
