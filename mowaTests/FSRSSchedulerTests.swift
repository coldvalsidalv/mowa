import XCTest
@testable import Verbum

/// Тесты математического ядра FSRS.
/// FSRSScheduler — core IP продукта. Тихая регрессия здесь = пользователи
/// учат слова слишком часто или слишком редко, не понимая почему.
final class FSRSSchedulerTests: XCTestCase {

    var scheduler: FSRSScheduler!
    var now: Date!

    override func setUp() {
        super.setUp()
        scheduler = FSRSScheduler()
        // Фиксированная дата для детерминированных тестов
        now = Date(timeIntervalSince1970: 1_700_000_000)
    }

    // MARK: - Новые карточки

    func test_newCard_again_goesToLearning() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .again, now: now)
        XCTAssertEqual(result.state, .learning)
    }

    func test_newCard_good_goesToReview() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertEqual(result.state, .review)
    }

    func test_newCard_easy_goesToReview() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .easy, now: now)
        XCTAssertEqual(result.state, .review)
    }

    func test_newCard_hard_goesToReview() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .hard, now: now)
        XCTAssertEqual(result.state, .review)
    }

    func test_newCard_repsIncrement() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertEqual(result.reps, 1)
    }

    func test_newCard_lastReviewSet() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertEqual(result.lastReview, now)
    }

    func test_scheduler_doesNotMutateInput() {
        let card = makeReviewCard()
        let originalStability = card.stability
        let originalDifficulty = card.difficulty
        _ = scheduler.schedule(card: card, rating: .again, now: now)
        XCTAssertEqual(card.stability, originalStability, "Snapshot должен оставаться неизменным")
        XCTAssertEqual(card.difficulty, originalDifficulty)
    }

    // MARK: - Stability при новых карточках

    func test_newCard_stabilityPositive() {
        for rating in [FSRSRating.again, .hard, .good, .easy] {
            let result = scheduler.schedule(card: makeNewCard(), rating: rating, now: now)
            XCTAssertGreaterThan(result.stability, 0, "stability должна быть > 0 для рейтинга \(rating)")
        }
    }

    func test_newCard_easyStabilityGreaterThanGood() {
        let easy = scheduler.schedule(card: makeNewCard(), rating: .easy, now: now)
        let good = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertGreaterThan(easy.stability, good.stability)
    }

    func test_newCard_goodStabilityGreaterThanHard() {
        let good = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        let hard = scheduler.schedule(card: makeNewCard(), rating: .hard, now: now)
        XCTAssertGreaterThan(good.stability, hard.stability)
    }

    // MARK: - Difficulty при новых карточках

    func test_newCard_difficultyInRange() {
        for rating in [FSRSRating.again, .hard, .good, .easy] {
            let result = scheduler.schedule(card: makeNewCard(), rating: rating, now: now)
            XCTAssertGreaterThanOrEqual(result.difficulty, 1.0, "difficulty должна быть >= 1 для рейтинга \(rating)")
            XCTAssertLessThanOrEqual(result.difficulty, 10.0, "difficulty должна быть <= 10 для рейтинга \(rating)")
        }
    }

    func test_newCard_againHardestDifficulty() {
        let again = scheduler.schedule(card: makeNewCard(), rating: .again, now: now)
        let easy = scheduler.schedule(card: makeNewCard(), rating: .easy, now: now)
        XCTAssertGreaterThan(again.difficulty, easy.difficulty)
    }

    // MARK: - Review карточки

    func test_reviewCard_again_goesToRelearning() {
        let result = scheduler.schedule(card: makeReviewCard(), rating: .again, now: now)
        XCTAssertEqual(result.state, .relearning)
    }

    func test_reviewCard_again_incrementsLapses() {
        let card = makeReviewCard()
        let result = scheduler.schedule(card: card, rating: .again, now: now)
        XCTAssertEqual(result.lapses, card.lapses + 1)
    }

    func test_reviewCard_good_staysInReview() {
        let result = scheduler.schedule(card: makeReviewCard(), rating: .good, now: now)
        XCTAssertEqual(result.state, .review)
    }

    func test_reviewCard_good_increasesStability() {
        let card = makeReviewCard()
        let result = scheduler.schedule(card: card, rating: .good, now: now)
        XCTAssertGreaterThan(result.stability, card.stability)
    }

    func test_reviewCard_again_decreasesStability() {
        let card = makeReviewCard()
        let result = scheduler.schedule(card: card, rating: .again, now: now)
        XCTAssertLessThan(result.stability, card.stability)
    }

    func test_reviewCard_easyGreaterStabilityThanGood() {
        let easy = scheduler.schedule(card: makeReviewCard(), rating: .easy, now: now)
        let good = scheduler.schedule(card: makeReviewCard(), rating: .good, now: now)
        XCTAssertGreaterThan(easy.stability, good.stability)
    }

    // MARK: - Интервалы

    func test_interval_minimumOneDay() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .again, now: now)
        XCTAssertGreaterThanOrEqual(result.scheduledDays, 1)
    }

    func test_interval_dueInFuture() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertGreaterThan(result.due, now)
    }

    func test_interval_easyLongerThanGood() {
        let easy = scheduler.schedule(card: makeNewCard(), rating: .easy, now: now)
        let good = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertGreaterThanOrEqual(easy.scheduledDays, good.scheduledDays)
    }

    func test_interval_growsWithRepeatedGoodRatings() {
        var card = makeNewCard()
        var prevInterval = 0
        var reviewDate = now!

        for i in 0..<5 {
            card = scheduler.schedule(card: card, rating: .good, now: reviewDate)
            XCTAssertGreaterThan(card.scheduledDays, prevInterval,
                                 "Интервал должен расти с каждым повторением (итерация \(i))")
            reviewDate = card.due
            prevInterval = card.scheduledDays
        }
    }

    // MARK: - Граничные случаи

    func test_stabilityNeverExceedsLimit() {
        var card = makeReviewCard()
        card.stability = 36000.0 // Близко к лимиту (100 лет)
        let result = scheduler.schedule(card: card, rating: .easy, now: now)
        XCTAssertLessThanOrEqual(result.stability, 36500.0)
    }

    func test_difficultyNeverExceedsBounds() {
        // Многократный .again не должен выйти за 10
        var card = makeReviewCard()
        for _ in 0..<20 {
            card = scheduler.schedule(card: card, rating: .again, now: now)
        }
        XCTAssertLessThanOrEqual(card.difficulty, 10.0)

        // Многократный .easy не должен выйти за 1
        card = makeNewCard()
        for _ in 0..<20 {
            card = scheduler.schedule(card: card, rating: .easy, now: now)
        }
        XCTAssertGreaterThanOrEqual(card.difficulty, 1.0)
    }

    // MARK: - FSRSRating.from(score:)

    func test_ratingFromScore_perfect() {
        XCTAssertEqual(FSRSRating.from(score: 1.0), .easy)
    }

    func test_ratingFromScore_good() {
        XCTAssertEqual(FSRSRating.from(score: 0.8), .good)
    }

    func test_ratingFromScore_hard() {
        XCTAssertEqual(FSRSRating.from(score: 0.6), .hard)
    }

    func test_ratingFromScore_again() {
        XCTAssertEqual(FSRSRating.from(score: 0.3), .again)
    }

    func test_ratingFromScore_boundary_90() {
        XCTAssertEqual(FSRSRating.from(score: 0.9), .easy)
    }

    func test_ratingFromScore_boundary_70() {
        XCTAssertEqual(FSRSRating.from(score: 0.7), .good)
    }

    // MARK: - Helpers

    private func makeNewCard() -> FSRSCardSnapshot {
        FSRSCardData().snapshot()
    }

    private func makeReviewCard() -> FSRSCardSnapshot {
        FSRSCardSnapshot(
            state: .review,
            difficulty: 5.0,
            stability: 10.0,
            reps: 3,
            lapses: 0,
            lastReview: now.addingTimeInterval(-10 * 86400), // 10 дней назад
            due: now,
            scheduledDays: 10
        )
    }
}
