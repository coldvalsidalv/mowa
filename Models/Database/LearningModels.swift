import Foundation
import SwiftData

/// Оценки ответа пользователя
enum FSRSRating: Int, Codable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// Состояния карточки
enum FSRSState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// Структура DSR для карточки (SwiftData Model)
@Model
final class FSRSCardData {
    var state: FSRSState
    var difficulty: Double
    var stability: Double
    var reps: Int
    var lapses: Int
    var lastReview: Date?
    var due: Date
    var scheduledDays: Int
    
    init() {
        self.state = .new
        self.difficulty = 0.0
        self.stability = 0.0
        self.reps = 0
        self.lapses = 0
        self.due = Date()
        self.scheduledDays = 0
    }
}

/// Модель лексической единицы. Объединяет контент и алгоритмические метаданные.
@Model
final class VocabItem {
    @Attribute(.unique) var id: UUID
    var polish: String
    var translation: String
    var partOfSpeech: String
    var example: String
    var category: String
    
    // Педагогическая стратегия: фаза обучения (single-word -> cloze-test)
    var isClozeUnlocked: Bool
    
    @Relationship(deleteRule: .cascade)
    var fsrsData: FSRSCardData
    
    init(polish: String, translation: String, partOfSpeech: String, example: String, category: String) {
        self.id = UUID()
        self.polish = polish
        self.translation = translation
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.category = category
        self.isClozeUnlocked = false
        self.fsrsData = FSRSCardData()
    }
}

/// Лог ответов для аналитики и тренировки ML моделей (KARL)
@Model
final class ReviewLog {
    var cardId: UUID
    var rating: FSRSRating
    var reviewDate: Date
    var reviewDurationMs: Int
    
    init(cardId: UUID, rating: FSRSRating, reviewDate: Date, duration: Int) {
        self.cardId = cardId
        self.rating = rating
        self.reviewDate = reviewDate
        self.reviewDurationMs = duration
    }
}
