import Foundation
import SwiftData
import Combine
import SwiftUI

/// Сервис уровня бизнес-логики. Оркестрирует выборку из БД и работу FSRS.
@MainActor
final class LearningEngine: ObservableObject {
    private let modelContext: ModelContext
    private let scheduler = FSRSScheduler()
    
    @Published var sessionQueue: [VocabItem] = []
    @Published var sessionProgress: CGFloat = 0.0
    private var totalInSession: Int = 0
    
    init(context: ModelContext) {
        self.modelContext = context
    }
    
    /// Загрузка сессии (Смешивание Due карточек и порции New карточек)
    func buildSession(category: String? = nil, newCardsLimit: Int = 10) {
        let now = Date()
        
        // 1. Выборка карточек, которые пора повторять (due <= now)
        // Используем reps > 0 вместо state != .new для обхода бага компилятора SwiftData с enums
        let dueDescriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.fsrsData.due <= now && $0.fsrsData.reps > 0 },
            sortBy: [SortDescriptor(\.fsrsData.due, order: .forward)]
        )
        let dueCards = (try? modelContext.fetch(dueDescriptor)) ?? []
        
        // 2. Выборка новых карточек с лимитом
        var newDescriptor = FetchDescriptor<VocabItem>()
        
        // Используем reps == 0 для безопасного определения новых карточек на уровне SQLite
        if let cat = category {
            newDescriptor.predicate = #Predicate { $0.fsrsData.reps == 0 && $0.category == cat }
        } else {
            newDescriptor.predicate = #Predicate { $0.fsrsData.reps == 0 }
        }
        
        newDescriptor.fetchLimit = newCardsLimit
        let newCards = (try? modelContext.fetch(newDescriptor)) ?? []
        
        // Собираем очередь (сначала повторения, затем новые)
        self.sessionQueue = dueCards + newCards
        self.totalInSession = sessionQueue.count
        self.sessionProgress = 0.0
    }
    
    /// Обработка ответа пользователя
    func processAnswer(item: VocabItem, rating: FSRSRating, timeSpentMs: Int) {
        let now = Date()
        
        // 1. Расчет новых параметров памяти через FSRS
        let updatedFSRS = scheduler.schedule(card: item.fsrsData, rating: rating, now: now)
        
        // Присваиваем новые значения объекту БД (SwiftData автоматически отследит изменения)
        item.fsrsData.difficulty = updatedFSRS.difficulty
        item.fsrsData.stability = updatedFSRS.stability
        item.fsrsData.state = updatedFSRS.state
        item.fsrsData.lapses = updatedFSRS.lapses
        item.fsrsData.reps = updatedFSRS.reps
        item.fsrsData.due = updatedFSRS.due
        item.fsrsData.lastReview = updatedFSRS.lastReview
        item.fsrsData.scheduledDays = updatedFSRS.scheduledDays
        
        // 2. Педагогическая стратегия: Анлок Cloze-тестов, если стабильность достигла уровня > 7 дней
        if updatedFSRS.stability > 7.0 && !item.isClozeUnlocked {
            item.isClozeUnlocked = true
        }
        
        // 3. Запись лога для аналитики
        let log = ReviewLog(cardId: item.id, rating: rating, reviewDate: now, duration: timeSpentMs)
        modelContext.insert(log)
        
        // 4. Управление очередью сессии
        sessionQueue.removeAll { $0.id == item.id }
        
        if rating == .again {
            // "Желаемое затруднение": Возвращаем в конец очереди с небольшим смещением
            sessionQueue.append(item)
            totalInSession += 1 // Увеличиваем знаменатель для прогресс-бара
        } else {
            StreakManager.shared.completeLesson() // Начисление XP только за успех
        }
        
        updateProgress()
        
        // 5. Сохранение изменений в БД
        try? modelContext.save()
    }
    
    private func updateProgress() {
        guard totalInSession > 0 else {
            sessionProgress = 1.0
            return
        }
        let completed = totalInSession - sessionQueue.count
        sessionProgress = CGFloat(completed) / CGFloat(totalInSession)
    }
}
