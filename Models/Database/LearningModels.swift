import Foundation
import SwiftData

/// User's answer ratings
enum FSRSRating: Int, Codable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    /// Converts a grammar quiz result into an FSRS rating
    static func from(score: Double) -> FSRSRating {
        switch score {
        case 0.9...: return .easy
        case 0.7..<0.9: return .good
        case 0.5..<0.7: return .hard
        default: return .again
        }
    }
}

/// Card states
enum FSRSState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// DSR data for a card (SwiftData Model)
@Model
final class FSRSCardData {
    var state: FSRSState
    var difficulty: Double
    var stability: Double
    var reps: Int
    var lapses: Int
    var lastReview: Date?
    var due: Date
    /// Current learning/relearning step. nil for .new and .review.
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

/// Immutable snapshot of FSRSCardData for calculations.
/// FSRSCardData is an @Model (reference type), which makes the scheduler function
/// accidentally mutating. The snapshot isolates the pure math from the ORM.
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

/// Lexical-item model. Combines content and algorithmic metadata.
@Model
final class VocabItem {
    @Attribute(.unique) var id: UUID
    /// Teenybase UUID — used for upsert during sync
    var remoteId: String?
    var polish: String
    var translation: String
    var partOfSpeech: String
    var example: String
    var category: String
    /// Order within a category by frequency (1 = most frequent)
    var rank: Int = 0
    /// Key inflections: {"1sg":"czytam","3sg":"czyta","past":"czytał","imp":"czytaj"}
    var inflections: String = "{}"
    
    // Pedagogical strategy: learning phase (single-word -> cloze-test)
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

/// FSRS progress for a grammar lesson
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

/// Answer log for analytics and training ML models (KARL)
@Model
final class ReviewLog {
    var cardId: UUID
    var rating: FSRSRating
    var reviewDate: Date
    var reviewDurationMs: Int
    /// Teenybase user id the answer was made under. Without it, when switching accounts
    /// on one device, user A's logs would sync to the server under user B's user_id.
    /// Optional for a lightweight migration of old records.
    var userId: String?

    init(cardId: UUID, rating: FSRSRating, reviewDate: Date, duration: Int, userId: String? = nil) {
        self.cardId = cardId
        self.rating = rating
        self.reviewDate = reviewDate
        self.reviewDurationMs = duration
        self.userId = userId
    }
}
