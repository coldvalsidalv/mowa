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
    
    init(categories: [String], isReviewMode: Bool, context: ModelContext) {
        // Инициализируем бизнес-логику с доступом к БД
        self.engine = LearningEngine(context: context)
        self.sessionStartTime = Date()
        
        // Запускаем сборку сессии
        // Если категорий несколько, берем первую для демо, либо модифицируем LearningEngine для массива
        self.engine.buildSession(category: categories.first, newCardsLimit: 15)
        self.bindEngineState()
    }
    
    private func bindEngineState() {
        // Синхронизация состояния движка с UI
        if let first = engine.sessionQueue.first {
            self.currentWord = first
            self.sessionStartTime = Date()
        } else {
            self.isFinished = true
        }
    }
    
    func submitRating(_ rating: FSRSRating) {
        guard let word = currentWord else { return }
        
        // Расчет времени, затраченного на ответ (в миллисекундах)
        let timeSpentMs = Int(Date().timeIntervalSince(sessionStartTime) * 1000)
        
        // Передаем данные в математическое ядро
        engine.processAnswer(item: word, rating: rating, timeSpentMs: timeSpentMs)
        
        // Обновляем UI
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
