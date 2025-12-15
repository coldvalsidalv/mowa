import Foundation

// Тип слайда: Теория или Тест
enum GrammarStepType: String, Codable {
    case theory
    case quiz
}

// Один шаг (слайд) урока
struct GrammarStep: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    let type: GrammarStepType
    
    // Поля для теории
    let title: String
    let content: String
    
    // Поля для квиза
    let question: String?
    let answers: [String]?
    let correctAnswer: String?
}

// Модель самого урока
struct GrammarLesson: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let level: String
    let steps: [GrammarStep]
}
