import Foundation
import SwiftData

/// Оценки ответа пользователя
enum FSRSRating: Int, Codable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    /// Конвертирует результат грамматического теста в рейтинг FSRS
    static func from(score: Double) -> FSRSRating {
        switch score {
        case 0.9...: return .easy
        case 0.7..<0.9: return .good
        case 0.5..<0.7: return .hard
        default: return .again
        }
    }
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
    /// Текущий learning/relearning step. nil для .new и .review.
    var step: Int?

    init() {
        self.state = .new
        self.difficulty = 0.0
        self.stability = 0.0
        self.reps = 0
        self.lapses = 0
        self.due = Date()
        self.step = nil
    }
}

/// Иммутабельный снимок FSRSCardData для расчётов.
/// FSRSCardData — @Model (ссылочный тип), что делает scheduler-функцию
/// случайно мутирующей. Снимок изолирует чистую математику от ORM.
struct FSRSCardSnapshot {
    var state: FSRSState
    var difficulty: Double
    var stability: Double
    var reps: Int
    var lapses: Int
    var lastReview: Date?
    var due: Date
    var step: Int?
}

extension FSRSCardData {
    func snapshot() -> FSRSCardSnapshot {
        FSRSCardSnapshot(
            state: state,
            difficulty: difficulty,
            stability: stability,
            reps: reps,
            lapses: lapses,
            lastReview: lastReview,
            due: due,
            step: step
        )
    }

    func apply(_ s: FSRSCardSnapshot) {
        state = s.state
        difficulty = s.difficulty
        stability = s.stability
        reps = s.reps
        lapses = s.lapses
        lastReview = s.lastReview
        due = s.due
        step = s.step
    }
}

/// Модель лексической единицы. Объединяет контент и алгоритмические метаданные.
@Model
final class VocabItem {
    @Attribute(.unique) var id: UUID
    /// UUID из Teenybase — используется для upsert при синхронизации
    var remoteId: String?
    var polish: String
    var translation: String
    var partOfSpeech: String
    var example: String
    var category: String
    /// Порядок внутри категории по частотности (1 = самое частое)
    var rank: Int = 0
    /// Ключевые флексии: {"1sg":"czytam","3sg":"czyta","past":"czytał","imp":"czytaj"}
    var inflections: String = "{}"
    
    // Педагогическая стратегия: фаза обучения (single-word -> cloze-test)
    var isClozeUnlocked: Bool
    
    @Relationship(deleteRule: .cascade)
    var fsrsData: FSRSCardData
    
    init(polish: String, translation: String, partOfSpeech: String, example: String, category: String, rank: Int = 0, inflections: String = "{}", remoteId: String? = nil) {
        self.id = UUID()
        self.remoteId = remoteId
        self.polish = polish
        self.translation = translation
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.category = category
        self.rank = rank
        self.inflections = inflections
        self.isClozeUnlocked = false
        self.fsrsData = FSRSCardData()
    }
}

/// FSRS прогресс по грамматическому уроку
@Model
final class GrammarProgress {
    @Attribute(.unique) var lessonId: String
    var lessonTitle: String
    var lessonLevel: String
    var lastScore: Double

    @Relationship(deleteRule: .cascade)
    var fsrsData: FSRSCardData

    init(lessonId: String, lessonTitle: String, lessonLevel: String) {
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.lessonLevel = lessonLevel
        self.lastScore = 0.0
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
