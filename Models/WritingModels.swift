import Foundation
import SwiftData

// MARK: - Writing task (bundle content)

struct WritingTask: Codable, Identifiable, Hashable, Sendable {
    let taskId: String
    let type: String
    let level: String
    let prompt: String
    let requiredPoints: [String]
    let minWords: Int
    let maxWords: Int

    var id: String { taskId }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case type, level, prompt
        case requiredPoints = "required_points"
        case minWords = "min_words"
        case maxWords = "max_words"
    }
}

// MARK: - LLM feedback (response of /writing/grade)

struct WritingFeedback: Codable, Sendable {
    /// Официальные критерии B1 Pisanie (Państwowa Komisja), каждый 0–4.
    struct Scores: Codable, Sendable {
        let wykonanieZadania: Int
        let poprawnoscGramatyczna: Int
        let slownictwo: Int
        let styl: Int
        let ortografiaInterpunkcja: Int

        enum CodingKeys: String, CodingKey {
            case wykonanieZadania = "wykonanie_zadania"
            case poprawnoscGramatyczna = "poprawnosc_gramatyczna"
            case slownictwo, styl
            case ortografiaInterpunkcja = "ortografia_interpunkcja"
        }
    }
    struct WError: Codable, Sendable {
        let fragment: String
        let correction: String
        let type: String
        let explanation: String
    }

    let scores: Scores
    let overallPercent: Int
    let passedEstimate: Bool
    let wordCount: Int
    let errors: [WError]
    let improvedVersion: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case scores, errors, summary
        case overallPercent = "overall_percent"
        case passedEstimate = "passed_estimate"
        case wordCount = "word_count"
        case improvedVersion = "improved_version"
    }
}

// MARK: - Persisted attempt (local history)

@Model
final class WritingAttempt {
    @Attribute(.unique) var id: UUID
    var taskId: String
    var userText: String
    var date: Date
    var overallPercent: Int
    var passedEstimate: Bool
    /// Полный фидбэк JSON — чтобы перерисовать историю без повторного запроса.
    var feedbackJSON: String

    init(taskId: String, userText: String, feedback: WritingFeedback, feedbackJSON: String) {
        self.id = UUID()
        self.taskId = taskId
        self.userText = userText
        self.date = Date()
        self.overallPercent = feedback.overallPercent
        self.passedEstimate = feedback.passedEstimate
        self.feedbackJSON = feedbackJSON
    }
}
