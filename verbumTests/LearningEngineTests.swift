import Testing
import Foundation
import SwiftData
@testable import Verbum

/// Unit-тесты на LearningEngine.processAnswer — стали возможны после инъекции
/// зависимостей (StreakTracking / ReviewLogSyncing) в init. Раньше метод был
/// прибит к StreakManager.shared (UserDefaults) и ReviewLogSyncService.shared
/// (сеть), поэтому не тестировался.
///
/// Swift Testing (а не XCTest) — требуется инстанс движка + ModelContainer,
/// см. правило в IntegrationTests.swift.

// MARK: - Test doubles

@MainActor
private final class SpyStreakTracker: StreakTracking {
    private(set) var completeCount = 0
    func completeLesson() { completeCount += 1 }
}

@MainActor
private final class SpyReviewLogSync: ReviewLogSyncing {
    private(set) var syncCount = 0
    func syncIfNeeded(context: ModelContext) { syncCount += 1 }
}

// MARK: - Suite

@Suite("LearningEngine — processAnswer")
@MainActor
struct LearningEngineTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: VocabItem.self, ReviewLog.self, GrammarProgress.self,
            configurations: config
        )
    }

    private func makeWord() -> VocabItem {
        VocabItem(polish: "czytać", translation: "читать", partOfSpeech: "verb",
                  example: "—", category: "A1")
    }

    private func reviewLogCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<ReviewLog>())
    }

    @Test("успешный ответ продвигает FSRS, пишет лог, дёргает streak и sync")
    func goodAnswerAdvancesAndSyncs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let word = makeWord()
        context.insert(word)
        try context.save()

        let streak = SpyStreakTracker()
        let sync = SpyReviewLogSync()
        let engine = LearningEngine(context: context,
                                    params: .defaults,
                                    streakTracker: streak,
                                    reviewLogSync: sync)

        engine.processAnswer(item: word, rating: .good, timeSpentMs: 1200)

        #expect(word.fsrsData.reps == 1, "новая карточка после ответа получает reps=1")
        #expect(word.fsrsData.state != .new, "карточка ушла из состояния .new")
        #expect(try reviewLogCount(context) == 1, "ровно один ReviewLog вставлен")
        #expect(streak.completeCount == 1, "успех продлевает streak")
        #expect(sync.syncCount == 1, "пустая очередь в конце сессии триггерит sync логов")
    }

    @Test("ответ .again возвращает карточку в очередь и не трогает streak")
    func againRequeuesWithoutStreak() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let word = makeWord()
        context.insert(word)
        try context.save()

        let streak = SpyStreakTracker()
        let sync = SpyReviewLogSync()
        let engine = LearningEngine(context: context,
                                    params: .defaults,
                                    streakTracker: streak,
                                    reviewLogSync: sync)
        engine.buildSession()
        #expect(engine.sessionQueue.count == 1)

        engine.processAnswer(item: word, rating: .again, timeSpentMs: 800)

        #expect(engine.sessionQueue.contains { $0.id == word.id },
                ".again возвращает карточку в очередь")
        #expect(streak.completeCount == 0, ".again не считается за успех")
        #expect(sync.syncCount == 0, "очередь не пуста — sync не запускается")
        #expect(try reviewLogCount(context) == 1)
    }

    @Test("повторные .again перестают возвращать карточку после cap")
    func againStopsAtSessionCap() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let word = makeWord()
        context.insert(word)
        try context.save()

        let streak = SpyStreakTracker()
        let sync = SpyReviewLogSync()
        let engine = LearningEngine(context: context,
                                    params: .defaults,
                                    streakTracker: streak,
                                    reviewLogSync: sync)
        engine.buildSession()

        // cap = VerbumConfig.fsrsMaxAgainRepeatsPerSession (3): первые 3 .again
        // возвращают карточку, 4-й — уже нет.
        let cap = VerbumConfig.fsrsMaxAgainRepeatsPerSession
        for _ in 0..<cap {
            engine.processAnswer(item: word, rating: .again, timeSpentMs: 500)
            #expect(engine.sessionQueue.contains { $0.id == word.id })
        }
        engine.processAnswer(item: word, rating: .again, timeSpentMs: 500)

        #expect(engine.sessionQueue.isEmpty, "после cap-раз .again карточка не возвращается")
        #expect(sync.syncCount == 1, "опустевшая очередь один раз триггерит sync")
        #expect(try reviewLogCount(context) == cap + 1, "каждый ответ пишет лог")
    }
}
