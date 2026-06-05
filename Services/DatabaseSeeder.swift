import Foundation
import SwiftData

@MainActor
final class DatabaseSeeder {
    static let shared = DatabaseSeeder()

    private let bundleSeedKey = "isDatabaseSeeded_v2"
    private let apiSeedKey    = "isDatabaseSeeded_api_v2"

    private init() {}

    // MARK: - Public

    func seedIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard

        // Уже засеяно текущей версией — пропускаем
        guard !defaults.bool(forKey: bundleSeedKey),
              !defaults.bool(forKey: apiSeedKey) else { return }

        // Сносим старые данные если была предыдущая версия сида
        let hasPreviousSeed = defaults.bool(forKey: "isDatabaseSeeded_v1")
            || defaults.bool(forKey: "isDatabaseSeeded_api_v1")
        if hasPreviousSeed {
            if let items = try? context.fetch(FetchDescriptor<VocabItem>()) {
                items.forEach { context.delete($0) }
                try? context.save()
            }
            defaults.removeObject(forKey: "isDatabaseSeeded_v1")
            defaults.removeObject(forKey: "isDatabaseSeeded_api_v1")
            print("🗑️ DatabaseSeeder: cleared old v1 data")
        }

        Task {
            await seedFromAPIOrBundle(context: context)
        }
    }

    // MARK: - Internal

    private func seedFromAPIOrBundle(context: ModelContext) async {
        print("🌱 DatabaseSeeder: starting seed...")

        let bundleWords = DataManager.shared.loadInitialWordsFromBundle()

        do {
            let apiWords = try await APIClient.shared.fetchAllWords()
            guard !apiWords.isEmpty else { throw APIError.serverError(0) }

            // Предпочитаем бандл если в нём больше слов (бандл = актуальный контент)
            if bundleWords.count > apiWords.count {
                print("📦 DatabaseSeeder: bundle (\(bundleWords.count)) > API (\(apiWords.count)), using bundle")
                insert(words: bundleWords, context: context)
                UserDefaults.standard.set(true, forKey: bundleSeedKey)
            } else {
                insert(words: apiWords, context: context)
                UserDefaults.standard.set(true, forKey: apiSeedKey)
                print("✅ DatabaseSeeder: seeded \(apiWords.count) words from API")
            }
        } catch {
            print("⚠️ DatabaseSeeder: API unavailable, using bundle")
            guard !bundleWords.isEmpty else {
                print("❌ DatabaseSeeder: bundle is empty")
                return
            }
            insert(words: bundleWords, context: context)
            UserDefaults.standard.set(true, forKey: bundleSeedKey)
            print("✅ DatabaseSeeder: seeded \(bundleWords.count) words from bundle")
        }
    }


    private func insert(words: [WordItemDTO], context: ModelContext) {
        for dto in words {
            let item = VocabItem(
                polish: dto.polish,
                translation: dto.translation,
                partOfSpeech: dto.partOfSpeech,
                example: dto.example,
                category: dto.category
            )
            // Аппроксимация старого box-прогресса в FSRS (для bundle-данных с legacy полями)
            if let box = dto.box, box > 0 {
                item.fsrsData.state = .review
                item.fsrsData.stability = Double(box * 2)
                item.fsrsData.difficulty = 5.0
            }
            context.insert(item)
        }
        do {
            try context.save()
        } catch {
            print("❌ DatabaseSeeder: save failed — \(error)")
        }
    }
}
