import Foundation

/// Временная структура (DTO) исключительно для парсинга JSON.
struct WordItemDTO: Codable {
    let id: Int
    let category: String
    let polish: String
    let translation: String
    let transcription: String
    let example: String
    let imageName: String
    let partOfSpeech: String
    let examplesList: [String]

    // Legacy поля из старого box-алгоритма
    var box: Int?
    var nextReview: Int?
    var lastReview: Int?
}

final class DataManager {
    static let shared = DataManager()
    private init() {}

    // MARK: - Bundle (fallback)

    func loadInitialWordsFromBundle() -> [WordItemDTO] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WordItemDTO].self, from: data) else {
            print("❌ DataManager: failed to read words.json from bundle")
            return []
        }
        return words
    }

    // MARK: - Grammar (API-first, bundle fallback)

    func loadGrammar() -> [GrammarLesson] {
        loadGrammarFromBundle()
    }

    /// Async вариант: пробует API, при недоступности возвращает бандл.
    func loadGrammarAsync() async -> [GrammarLesson] {
        do {
            let lessons = try await APIClient.shared.fetchAllGrammarLessons()
            if !lessons.isEmpty { return lessons }
        } catch {
            print("⚠️ DataManager: grammar API unavailable — \(error)")
        }
        return loadGrammarFromBundle()
    }

    private func loadGrammarFromBundle() -> [GrammarLesson] {
        guard let url = Bundle.main.url(forResource: "grammar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lessons = try? JSONDecoder().decode([GrammarLesson].self, from: data) else {
            print("❌ DataManager: failed to read grammar.json from bundle")
            return []
        }
        return lessons
    }
}
