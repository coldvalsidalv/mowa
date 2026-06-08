import Foundation

/// Структура для декодирования words.json из бандла (offline fallback).
struct BundleWord: Decodable, Sendable {
    let polish: String
    let translation: String
    let transcription: String
    let example: String
    let partOfSpeech: String
    let category: String
    let rank: Int
    let inflections: [String: String]
}

final class DataManager: Sendable {
    nonisolated static let shared = DataManager()
    nonisolated private init() {}

    // MARK: - Vocabulary (offline fallback для VocabSyncService)

    func loadWordsFromBundle() -> [BundleWord] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([BundleWord].self, from: data) else {
            print("❌ DataManager: failed to read words.json from bundle")
            return []
        }
        return words
    }

    // MARK: - Grammar

    nonisolated func loadGrammar() -> [GrammarLesson] {
        guard let url = Bundle.main.url(forResource: "grammar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lessons = try? JSONDecoder().decode([GrammarLesson].self, from: data) else {
            print("❌ DataManager: failed to read grammar.json from bundle")
            return []
        }
        return lessons
    }

    func loadGrammarAsync() async -> [GrammarLesson] {
        do {
            let lessons = try await APIClient.shared.fetchAllGrammarLessons()
            if !lessons.isEmpty { return lessons }
        } catch {
            print("⚠️ DataManager: grammar API unavailable — \(error)")
        }
        return loadGrammar()
    }
}
