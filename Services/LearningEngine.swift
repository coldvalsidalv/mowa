import Foundation
import SwiftData
import Combine
import SwiftUI

// MARK: - Review Tier

enum ReviewTier {
    case all            // умный микс: due + new
    case category(String) // конкретная тема
    case weak           // state == relearning || difficulty > 7
    case medium         // review, stability < 14
    case strong         // review, stability >= 14
}

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

    // MARK: - Session builders

    /// Стандартная сессия: due-карточки + новые из категории
    func buildSession(category: String? = nil, newCardsLimit: Int = 10) {
        let now = Date()

        let dueDescriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.fsrsData.due <= now && $0.fsrsData.reps > 0 },
            sortBy: [SortDescriptor(\.fsrsData.due, order: .forward)]
        )
        var dueCards = (try? modelContext.fetch(dueDescriptor)) ?? []

        // Фильтруем по категории если задана
        if let cat = category {
            dueCards = dueCards.filter { $0.category == cat }
        }

        var newDescriptor = FetchDescriptor<VocabItem>()
        if let cat = category {
            newDescriptor.predicate = #Predicate { $0.fsrsData.reps == 0 && $0.category == cat }
        } else {
            newDescriptor.predicate = #Predicate { $0.fsrsData.reps == 0 }
        }
        newDescriptor.fetchLimit = newCardsLimit
        let newCards = (try? modelContext.fetch(newDescriptor)) ?? []

        self.sessionQueue = dueCards + newCards
        self.totalInSession = sessionQueue.count
        self.sessionProgress = 0.0
    }

    /// Сессия повторения по FSRS-уровню (weak/medium/strong/all)
    func buildReviewSession(tier: ReviewTier) {
        let now = Date()

        // Получаем все due-карточки из памяти, фильтруем по tier в Swift
        // (SwiftData не поддерживает предикаты на enum .rawValue в nested @Model)
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.fsrsData.reps > 0 && $0.fsrsData.due <= now },
            sortBy: [SortDescriptor(\.fsrsData.due, order: .forward)]
        )
        let allDue = (try? modelContext.fetch(descriptor)) ?? []

        let filtered: [VocabItem]
        switch tier {
        case .all:
            filtered = allDue
        case .category(let cat):
            filtered = allDue.filter { $0.category == cat }
        case .weak:
            filtered = allDue.filter {
                $0.fsrsData.state == .relearning || $0.fsrsData.difficulty > 7.0
            }
        case .medium:
            filtered = allDue.filter {
                $0.fsrsData.state == .review &&
                $0.fsrsData.difficulty <= 7.0 &&
                $0.fsrsData.stability < 14.0
            }
        case .strong:
            filtered = allDue.filter {
                $0.fsrsData.state == .review &&
                $0.fsrsData.stability >= 14.0
            }
        }

        self.sessionQueue = filtered
        self.totalInSession = sessionQueue.count
        self.sessionProgress = 0.0
    }

    // MARK: - Answer processing

    func processAnswer(item: VocabItem, rating: FSRSRating, timeSpentMs: Int) {
        let now = Date()

        // Сохраняем старую stability ДО мутации — нужна для отслеживания перехода порога
        let oldStability = item.fsrsData.stability

        let updatedFSRS = scheduler.schedule(card: item.fsrsData, rating: rating, now: now)

        item.fsrsData.difficulty    = updatedFSRS.difficulty
        item.fsrsData.stability     = updatedFSRS.stability
        item.fsrsData.state         = updatedFSRS.state
        item.fsrsData.lapses        = updatedFSRS.lapses
        item.fsrsData.reps          = updatedFSRS.reps
        item.fsrsData.due           = updatedFSRS.due
        item.fsrsData.lastReview    = updatedFSRS.lastReview
        item.fsrsData.scheduledDays = updatedFSRS.scheduledDays

        if updatedFSRS.stability > 7.0 && !item.isClozeUnlocked {
            item.isClozeUnlocked = true
        }

        // Отслеживаем переход через порог "знаю" (stability = 3 дня)
        // Порог выбран так: слово пережило минимум 2 успешных повторения с интервалом ~3 дня
        updateLearnedWordsCounter(oldStability: oldStability, newStability: updatedFSRS.stability)

        let log = ReviewLog(cardId: item.id, rating: rating, reviewDate: now, duration: timeSpentMs)
        modelContext.insert(log)

        sessionQueue.removeAll { $0.id == item.id }

        if rating == .again {
            sessionQueue.append(item)
            totalInSession += 1
        } else {
            StreakManager.shared.completeLesson()
        }

        updateProgress()

        do {
            try modelContext.save()
        } catch {
            print("❌ LearningEngine: failed to save context — \(error)")
        }
    }

    /// Порог знания: stability ≥ 3 дня.
    /// Слово пересекает порог вверх → +1. Вниз (забыто) → −1.
    private func updateLearnedWordsCounter(oldStability: Double, newStability: Double) {
        let threshold = 3.0
        let wasKnown = oldStability >= threshold
        let isKnown  = newStability >= threshold

        guard wasKnown != isKnown else { return }

        let current = UserDefaults.standard.integer(forKey: StorageKeys.totalLearnedWords)
        if isKnown {
            UserDefaults.standard.set(current + 1, forKey: StorageKeys.totalLearnedWords)
        } else {
            UserDefaults.standard.set(max(0, current - 1), forKey: StorageKeys.totalLearnedWords)
        }
    }

    private func updateProgress() {
        guard totalInSession > 0 else { sessionProgress = 1.0; return }
        let completed = totalInSession - sessionQueue.count
        sessionProgress = CGFloat(completed) / CGFloat(totalInSession)
    }
}
