import SwiftUI
import SwiftData
import Combine

@MainActor
final class FlashcardViewModel: ObservableObject {
    @Published var currentWord: VocabItem?
    @Published var isFinished = false
    @Published var progress: CGFloat = 0.0

    private let engine: LearningEngine
    private var sessionStartTime: Date

    /// Обычный режим — по категориям + новые карточки
    init(categories: [String], isReviewMode: Bool, context: ModelContext) {
        self.engine = LearningEngine(context: context)
        self.sessionStartTime = Date()

        if isReviewMode {
            engine.buildReviewSession(tier: .all)
        } else {
            engine.buildSession(category: categories.first, newCardsLimit: 15)
        }
        bindEngineState()
    }

    /// Режим повторения по FSRS-уровню (weak / medium / strong)
    init(tier: ReviewTier, context: ModelContext) {
        self.engine = LearningEngine(context: context)
        self.sessionStartTime = Date()
        engine.buildReviewSession(tier: tier)
        bindEngineState()
    }

    private func bindEngineState() {
        if let first = engine.sessionQueue.first {
            self.currentWord = first
            self.sessionStartTime = Date()
        } else {
            self.isFinished = true
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
        }
    }
}
