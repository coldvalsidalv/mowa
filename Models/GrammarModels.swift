import Foundation

// Slide type: Theory or Quiz
enum GrammarStepType: String, Codable {
    case theory
    case quiz
}

// A single lesson step (slide)
struct GrammarStep: Identifiable, Codable, Hashable, Sendable {
    var id: String = UUID().uuidString
    let type: GrammarStepType

    // Theory fields
    let title: String
    let content: String

    // Quiz fields
    let question: String?
    let answers: [String]?
    let correctAnswer: String?
}

// The lesson model itself
struct GrammarLesson: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String
    let level: String
    let steps: [GrammarStep]
}
