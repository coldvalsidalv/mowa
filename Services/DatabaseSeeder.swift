import Foundation
import SwiftData

@MainActor
final class DatabaseSeeder {
    static let shared = DatabaseSeeder()

    private let bundleSeedKey = "isDatabaseSeeded_v1"
    private let apiSeedKey    = "isDatabaseSeeded_api_v1"

    private init() {}

    // MARK: - Public

    func seedIfNeeded(context: ModelContext) {
        // Уже засеяно (из API или из бандла) — пропускаем
        guard !UserDefaults.standard.bool(forKey: bundleSeedKey),
              !UserDefaults.standard.bool(forKey: apiSeedKey) else { return }

        Task {
            await seedFromAPIOrBundle(context: context)
        }
    }

    // MARK: - Internal

    private func seedFromAPIOrBundle(context: ModelContext) async {
        print("🌱 DatabaseSeeder: starting seed...")

        do {
            let words = try await APIClient.shared.fetchAllWords()
            guard !words.isEmpty else { throw APIError.serverError(0) }
            insert(words: words, context: context)
            UserDefaults.standard.set(true, forKey: apiSeedKey)
            print("✅ DatabaseSeeder: seeded \(words.count) words from API")
        } catch {
            print("⚠️ DatabaseSeeder: API unavailable (\(error)), falling back to bundle")
            seedFromBundle(context: context)
        }
    }

    private func seedFromBundle(context: ModelContext) {
        let words = DataManager.shared.loadInitialWordsFromBundle()
        guard !words.isEmpty else {
            print("❌ DatabaseSeeder: bundle words.json is empty")
            return
        }
        insert(words: words, context: context)
        UserDefaults.standard.set(true, forKey: bundleSeedKey)
        print("✅ DatabaseSeeder: seeded \(words.count) words from bundle")
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
