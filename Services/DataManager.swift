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
            verbumLog("❌ DataManager: failed to read words.json from bundle")
            return []
        }
        return words
    }

    // MARK: - Grammar

    nonisolated func loadGrammar() -> [GrammarLesson] {
        guard let url = Bundle.main.url(forResource: "grammar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lessons = try? JSONDecoder().decode([GrammarLesson].self, from: data) else {
            verbumLog("❌ DataManager: failed to read grammar.json from bundle")
            return []
        }
        return lessons
    }

    func loadGrammarAsync() async -> [GrammarLesson] {
        do {
            let lessons = try await APIClient.shared.fetchAllGrammarLessons()
            if !lessons.isEmpty { return lessons }
        } catch {
            verbumLog("⚠️ DataManager: grammar API unavailable — \(error)")
        }
        return loadGrammar()
    }

    // MARK: - Exam sessions

    nonisolated func loadExamSessions() -> [ExamSession] {
        guard let url = Bundle.main.url(forResource: "exam_sessions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([BundleExamSession].self, from: data) else {
            verbumLog("❌ DataManager: failed to read exam_sessions.json from bundle")
            return []
        }
        return raw.compactMap(ExamSessionParser.from)
    }

    /// API-first с фоллбэком на бандл (даты экзаменов синхронизируются с бэкенда).
    func loadExamSessionsAsync() async -> [ExamSession] {
        do {
            let sessions = try await APIClient.shared.fetchAllExamSessions()
            if !sessions.isEmpty { return sessions }
        } catch {
            verbumLog("⚠️ DataManager: exam sessions API unavailable — \(error)")
        }
        return loadExamSessions()
    }
}
