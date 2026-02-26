import Foundation

/// Временная структура (DTO) исключительно для парсинга начального JSON.
/// Она НЕ должна использоваться в UI или бизнес-логике.
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
    
    // Старые поля (если они присутствуют в JSON)
    var box: Int?
    var nextReview: Int?
    var lastReview: Int?
}

final class DataManager {
    static let shared = DataManager()
    
    private init() {}
    
    /// Читает сырые данные из бандла для первоначального заполнения базы SwiftData
    func loadInitialWordsFromBundle() -> [WordItemDTO] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WordItemDTO].self, from: data) else {
            print("❌ Ошибка чтения words.json из Bundle")
            return []
        }
        return words
    }
    
    /// Грамматика остается read-only из бандла (прогресс хранится в UserDefaults)
    func loadGrammar() -> [GrammarLesson] {
        guard let url = Bundle.main.url(forResource: "grammar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lessons = try? JSONDecoder().decode([GrammarLesson].self, from: data) else {
            print("❌ Ошибка чтения grammar.json из Bundle")
            return []
        }
        return lessons
    }
}
