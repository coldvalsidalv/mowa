import SwiftUI
import SwiftData
import Combine

@MainActor
final class FlashcardViewModel: ObservableObject {
    @Published var currentWord: VocabItem?
    @Published var isFinished = false
    @Published var progress: CGFloat = 0.0
    @Published var remainingNewCards: Int = 0

    private let engine: LearningEngine
    private var sessionStartTime: Date
    private var category: String?
    /// Target exam level. When set — the session is built by level,
    /// not by category.
    private var level: String?
    private let batchSize = 20

    /// Normal mode — by categories + new cards
    init(categories: [String], isReviewMode: Bool, context: ModelContext) {
        self.engine = LearningEngine(context: context)
        self.sessionStartTime = Date()
        self.category = categories.first

        if isReviewMode {
            engine.buildReviewSession(tier: .all)
        } else {
            engine.buildSession(category: categories.first, newCardsLimit: batchSize)
        }
        bindEngineState()
        updateRemaining()
    }

    /// Exam mode — all words at the target CEFR level ("A2"/"B1"/"B2")
    init(level: String, context: ModelContext) {
        self.engine = LearningEngine(context: context)
        self.sessionStartTime = Date()
        self.level = level
        engine.buildSession(level: level, newCardsLimit: batchSize)
        bindEngineState()
        updateRemaining()
    }

    /// Review mode by FSRS level (weak / medium / strong)
    init(tier: ReviewTier, context: ModelContext) {
        self.engine = LearningEngine(context: context)
        self.sessionStartTime = Date()
        engine.buildReviewSession(tier: tier)
        bindEngineState()
    }

    func loadNextBatch() {
        if let level {
            engine.buildSession(level: level, newCardsLimit: batchSize)
        } else {
            engine.buildSession(category: category, newCardsLimit: batchSize)
        }
        bindEngineState()
        updateRemaining()
    }

    private func bindEngineState() {
        if let first = engine.sessionQueue.first {
            self.currentWord = first
            self.sessionStartTime = Date()
            self.isFinished = false
        } else {
            self.isFinished = true
        }
    }

    private func updateRemaining() {
        if let level {
            remainingNewCards = engine.countRemainingNew(level: level)
        } else {
            remainingNewCards = engine.countRemainingNew(category: category)
        }
    }

    func submitRating(_ rating: FSRSRating) {
        guard let word = currentWord else { return }
        let timeSpentMs = Int(Date().timeIntervalSince(sessionStartTime) * 1000)
        engine.processAnswer(item: word, rating: rating, timeSpentMs: timeSpentMs)
        self.progress = engine.sessionProgress

        if let next = engine.sessionQueue.first {
            self.currentWord = next
            self.sessionStartTime = Date()
        } else {
            self.currentWord = nil
            self.isFinished = true
            updateRemaining()
        }
    }
}
