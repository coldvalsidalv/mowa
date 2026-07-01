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

// MARK: - Injected collaborators

/// Consumer-owned абстракции (DIP): LearningEngine объявляет узкую поверхность,
/// которая ему нужна от side-effecting коллабораторов, чтобы тесты могли
/// подставить no-op/spy вместо синглтонов, лезущих в UserDefaults / Keychain / сеть.
@MainActor
protocol StreakTracking {
    func completeLesson()
}

@MainActor
protocol ReviewLogSyncing {
    func syncIfNeeded(context: ModelContext)
}

extension StreakManager: StreakTracking {}
extension ReviewLogSyncService: ReviewLogSyncing {}

/// Сервис уровня бизнес-логики. Оркестрирует выборку из БД и работу FSRS.
@MainActor
final class LearningEngine: ObservableObject {
    private let modelContext: ModelContext
    /// Снимок FSRS-параметров на момент создания engine (т.е. начала сессии).
    /// Hot-reload в середине сессии намеренно не делаем — оптимизатор перезаписывает
    /// параметры асинхронно, в середине сессии менять мат-модель опасно.
    private let scheduler: FSRSScheduler
    private let streakTracker: StreakTracking
    private let reviewLogSync: ReviewLogSyncing

    @Published var sessionQueue: [VocabItem] = []
    @Published var sessionProgress: CGFloat = 0.0
    private var totalInSession: Int = 0
    /// Сколько раз карточку уже повторяли в текущей сессии после .again.
    /// Нужно, чтобы не вернуть её в очередь больше cap-раз.
    private var againRetryCount: [UUID: Int] = [:]

    /// Зависимости опциональны с nil-дефолтом (а не `= .shared` в сигнатуре):
    /// дефолтный аргумент вычисляется в nonisolated-контексте и не может ссылаться
    /// на MainActor-isolated синглтоны. Резолвим их в теле init (оно MainActor).
    init(context: ModelContext,
         params: FSRSParams? = nil,
         streakTracker: StreakTracking? = nil,
         reviewLogSync: ReviewLogSyncing? = nil) {
        self.modelContext = context
        self.streakTracker = streakTracker ?? StreakManager.shared
        self.reviewLogSync = reviewLogSync ?? ReviewLogSyncService.shared
        let resolvedParams = params ?? FSRSParamStore.shared.current
        self.scheduler = FSRSScheduler(
            parameters: resolvedParams.parameters,
            desiredRetention: resolvedParams.desiredRetention,
            learningSteps: resolvedParams.learningSteps,
            relearningSteps: resolvedParams.relearningSteps
        )
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

        var newDescriptor = FetchDescriptor<VocabItem>(
            // Новые карточки — по частотности (rank 1 = самое частое слово),
            // иначе SwiftData возвращает произвольный порядок.
            sortBy: [SortDescriptor(\.rank, order: .forward)]
        )
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
        self.againRetryCount.removeAll()
    }

    /// Экзаменационная сессия: due + новые слова целевого уровня CEFR ("B1"/"B2").
    /// Фильтруем по префиксу category в самом #Predicate ("B1 " матчит "B1 · 4"),
    /// что позволяет вернуть fetchLimit на новых и не материализовать весь словарь.
    func buildSession(level: String, newCardsLimit: Int = 20) {
        let now = Date()
        let prefix = level + " "

        let dueDescriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate {
                $0.fsrsData.due <= now && $0.fsrsData.reps > 0 && $0.category.starts(with: prefix)
            },
            sortBy: [SortDescriptor(\.fsrsData.due, order: .forward)]
        )
        let dueCards = (try? modelContext.fetch(dueDescriptor)) ?? []

        var newDescriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate {
                $0.fsrsData.reps == 0 && $0.category.starts(with: prefix)
            },
            sortBy: [SortDescriptor(\.rank, order: .forward)]
        )
        newDescriptor.fetchLimit = newCardsLimit
        let newCards = (try? modelContext.fetch(newDescriptor)) ?? []

        self.sessionQueue = dueCards + newCards
        self.totalInSession = sessionQueue.count
        self.sessionProgress = 0.0
        self.againRetryCount.removeAll()
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
        self.againRetryCount.removeAll()
    }

    // MARK: - Helpers

    func countRemainingNew(category: String?) -> Int {
        var descriptor = FetchDescriptor<VocabItem>(
            predicate: category.map { cat in
                #Predicate { $0.fsrsData.reps == 0 && $0.category == cat }
            } ?? #Predicate { $0.fsrsData.reps == 0 }
        )
        descriptor.fetchLimit = 500
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Сколько новых (ещё не показанных) слов осталось на целевом уровне.
    /// Нужно для дневного плана подготовки к экзамену. fetchCount + префиксный
    /// предикат — без материализации словаря в память.
    func countRemainingNew(level: String) -> Int {
        let prefix = level + " "
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate {
                $0.fsrsData.reps == 0 && $0.category.starts(with: prefix)
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Answer processing

    func processAnswer(item: VocabItem, rating: FSRSRating, timeSpentMs: Int) {
        let now = Date()

        let updated = scheduler.schedule(card: item.fsrsData.snapshot(), rating: rating, now: now)
        item.fsrsData.apply(updated)

        if updated.stability >= VerbumConfig.fsrsClozeUnlockStability && !item.isClozeUnlocked {
            item.isClozeUnlocked = true
        }

        let log = ReviewLog(cardId: item.id, rating: rating, reviewDate: now, duration: timeSpentMs,
                            userId: KeychainHelper.load(KeychainKeys.userId))
        modelContext.insert(log)

        sessionQueue.removeAll { $0.id == item.id }

        if rating == .again {
            let retries = againRetryCount[item.id, default: 0]
            if retries < VerbumConfig.fsrsMaxAgainRepeatsPerSession {
                againRetryCount[item.id] = retries + 1
                sessionQueue.append(item)
                totalInSession += 1
            }
            // Иначе карточка получила forget-обновление и уйдёт в next due; в текущей сессии больше не показываем.
        } else {
            streakTracker.completeLesson()
        }

        updateProgress()

        do {
            try modelContext.save()
        } catch {
            verbumLog("❌ LearningEngine: failed to save context — \(error)")
        }

        // Конец сессии — отправляем накопленные ReviewLog'и на бэкенд.
        if sessionQueue.isEmpty {
            reviewLogSync.syncIfNeeded(context: modelContext)
        }
    }

    private func updateProgress() {
        guard totalInSession > 0 else { sessionProgress = 1.0; return }
        let completed = totalInSession - sessionQueue.count
        sessionProgress = CGFloat(completed) / CGFloat(totalInSession)
    }
}
