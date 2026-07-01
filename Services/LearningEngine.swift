import Foundation
import SwiftData
import Combine
import SwiftUI

// MARK: - Review Tier

enum ReviewTier {
    case all            // smart mix: due + new
    case category(String) // a specific topic
    case weak           // state == relearning || difficulty > 7
    case medium         // review, stability < 14
    case strong         // review, stability >= 14
}

// MARK: - Injected collaborators

/// Consumer-owned abstractions (DIP): LearningEngine declares the narrow surface
/// it needs from its side-effecting collaborators, so tests can substitute
/// no-op/spy doubles for the singletons that touch UserDefaults / Keychain / network.
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

/// Business-logic-level service. Orchestrates fetching from the DB and running FSRS.
@MainActor
final class LearningEngine: ObservableObject {
    private let modelContext: ModelContext
    /// Snapshot of FSRS params at engine creation (i.e. the start of the session).
    /// We deliberately avoid a mid-session hot-reload — the optimizer rewrites the
    /// params asynchronously, and changing the math model mid-session is risky.
    private let scheduler: FSRSScheduler
    private let streakTracker: StreakTracking
    private let reviewLogSync: ReviewLogSyncing

    @Published var sessionQueue: [VocabItem] = []
    @Published var sessionProgress: CGFloat = 0.0
    private var totalInSession: Int = 0
    /// How many times a card has been repeated in the current session after .again.
    /// Needed so we don't put it back in the queue more than cap times.
    private var againRetryCount: [UUID: Int] = [:]

    /// Dependencies are optional with a nil default (rather than `= .shared` in the
    /// signature): a default argument is evaluated in a nonisolated context and can't
    /// reference MainActor-isolated singletons. We resolve them in the init body (MainActor).
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

    /// Standard session: due cards + new ones from a category
    func buildSession(category: String? = nil, newCardsLimit: Int = 10) {
        let now = Date()

        let dueDescriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.fsrsData.due <= now && $0.fsrsData.reps > 0 },
            sortBy: [SortDescriptor(\.fsrsData.due, order: .forward)]
        )
        var dueCards = (try? modelContext.fetch(dueDescriptor)) ?? []

        // Filter by category if one is given
        if let cat = category {
            dueCards = dueCards.filter { $0.category == cat }
        }

        var newDescriptor = FetchDescriptor<VocabItem>(
            // New cards — by frequency (rank 1 = most frequent word),
            // otherwise SwiftData returns an arbitrary order.
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

    /// Exam session: due + new words at the target CEFR level ("B1"/"B2").
    /// We filter by the category prefix inside the #Predicate itself ("B1 " matches "B1 · 4"),
    /// which lets us apply fetchLimit to the new ones and avoid materializing the whole vocabulary.
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

    /// Review session by FSRS level (weak/medium/strong/all)
    func buildReviewSession(tier: ReviewTier) {
        let now = Date()

        // Fetch all due cards into memory and filter by tier in Swift
        // (SwiftData doesn't support predicates on enum .rawValue in a nested @Model)
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

    /// How many new (not-yet-shown) words remain at the target level.
    /// Needed for the daily exam-prep plan. fetchCount + a prefix predicate —
    /// without materializing the vocabulary into memory.
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
            // Otherwise the card got a forget update and moves to its next due; we don't show it again this session.
        } else {
            streakTracker.completeLesson()
        }

        updateProgress()

        do {
            try modelContext.save()
        } catch {
            verbumLog("❌ LearningEngine: failed to save context — \(error)")
        }

        // End of session — send the accumulated ReviewLogs to the backend.
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
