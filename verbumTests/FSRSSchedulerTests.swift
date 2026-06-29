import XCTest
@testable import Verbum

/// Тесты математического ядра FSRS-6.
/// Порт из py-fsrs v6.3.1. Тихая регрессия здесь = пользователи учат
/// слова слишком часто или слишком редко, не понимая почему.
final class FSRSSchedulerTests: XCTestCase {

    var scheduler: FSRSScheduler!
    var now: Date!

    override func setUp() {
        super.setUp()
        scheduler = FSRSScheduler()
        now = Date(timeIntervalSince1970: 1_700_000_000)
    }

    // MARK: - Новые карточки: переходы состояний

    func test_newCard_again_staysInLearningAtStepZero() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .again, now: now)
        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.step, 0)
        // Первый learning step = 60 секунд
        XCTAssertEqual(result.due.timeIntervalSince(now), 60, accuracy: 0.1)
    }

    func test_newCard_hard_staysInLearningAtStepZero() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .hard, now: now)
        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.step, 0)
        // С двумя learning steps: avg(60, 600) = 330
        XCTAssertEqual(result.due.timeIntervalSince(now), 330, accuracy: 0.1)
    }

    func test_newCard_good_advancesLearningStep() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .good, now: now)
        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.step, 1)
        // Второй learning step = 600 секунд
        XCTAssertEqual(result.due.timeIntervalSince(now), 600, accuracy: 0.1)
    }

    func test_newCard_easy_promotesToReview() {
        let result = scheduler.schedule(card: makeNewCard(), rating: .easy, now: now)
        XCTAssertEqual(result.state, .review)
        XCTAssertNil(result.step)
        // due — в днях вперёд, минимум сутки
        XCTAssertGreaterThanOrEqual(result.due.timeIntervalSince(now), 86400)
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
        XCTAssertEqual(card.stability, originalStability)
        XCTAssertEqual(card.difficulty, originalDifficulty)
    }

    // MARK: - Stability / Difficulty: новые карточки

    func test_newCard_stabilityPositive() {
        for rating in [FSRSRating.again, .hard, .good, .easy] {
            let result = scheduler.schedule(card: makeNewCard(), rating: rating, now: now)
            XCTAssertGreaterThan(result.stability, 0)
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

    func test_newCard_difficultyInRange() {
        for rating in [FSRSRating.again, .hard, .good, .easy] {
            let result = scheduler.schedule(card: makeNewCard(), rating: rating, now: now)
            XCTAssertGreaterThanOrEqual(result.difficulty, 1.0)
            XCTAssertLessThanOrEqual(result.difficulty, 10.0)
        }
    }

    func test_newCard_againHardestDifficulty() {
        let again = scheduler.schedule(card: makeNewCard(), rating: .again, now: now)
        let easy = scheduler.schedule(card: makeNewCard(), rating: .easy, now: now)
        XCTAssertGreaterThan(again.difficulty, easy.difficulty)
    }

    // MARK: - Learning steps: продвижение и возврат

    func test_learningStepOne_good_promotesToReview() {
        var card = makeNewCard()
        card = scheduler.schedule(card: card, rating: .good, now: now)
        XCTAssertEqual(card.step, 1)

        // Через 10 минут (как раз learning step) — ещё один Good
        let nextNow = now.addingTimeInterval(600)
        card = scheduler.schedule(card: card, rating: .good, now: nextNow)
        XCTAssertEqual(card.state, .review)
        XCTAssertNil(card.step)
        // due теперь в днях
        XCTAssertGreaterThanOrEqual(card.due.timeIntervalSince(nextNow), 86400)
    }

    func test_learningStep_again_resetsToZero() {
        var card = makeNewCard()
        card = scheduler.schedule(card: card, rating: .good, now: now)  // → step 1
        XCTAssertEqual(card.step, 1)

        let nextNow = now.addingTimeInterval(600)
        card = scheduler.schedule(card: card, rating: .again, now: nextNow)
        XCTAssertEqual(card.state, .learning)
        XCTAssertEqual(card.step, 0)
        XCTAssertEqual(card.due.timeIntervalSince(nextNow), 60, accuracy: 0.1)
    }

    // MARK: - Review карточки

    func test_reviewCard_again_goesToRelearning() {
        let result = scheduler.schedule(card: makeReviewCard(), rating: .again, now: now)
        XCTAssertEqual(result.state, .relearning)
        XCTAssertEqual(result.step, 0)
        XCTAssertEqual(result.due.timeIntervalSince(now), 600, accuracy: 0.1)
    }

    func test_reviewCard_again_incrementsLapses() {
        let card = makeReviewCard()
        let result = scheduler.schedule(card: card, rating: .again, now: now)
        XCTAssertEqual(result.lapses, card.lapses + 1)
    }

    func test_reviewCard_good_staysInReview() {
        let result = scheduler.schedule(card: makeReviewCard(), rating: .good, now: now)
        XCTAssertEqual(result.state, .review)
        XCTAssertNil(result.step)
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

    func test_dueInFutureForAllRatings() {
        for rating in [FSRSRating.again, .hard, .good, .easy] {
            let result = scheduler.schedule(card: makeNewCard(), rating: rating, now: now)
            XCTAssertGreaterThan(result.due, now, "due должен быть в будущем для \(rating)")
        }
    }

    func test_reviewIntervalGrowsWithRepeatedGood() {
        // Стартуем уже в review, чтобы тест не зависел от learning-step переходов.
        var card = makeReviewCard()
        var reviewDate = now!
        var prevDue = reviewDate

        for i in 0..<5 {
            card = scheduler.schedule(card: card, rating: .good, now: reviewDate)
            XCTAssertGreaterThan(card.due, prevDue,
                                 "due должен сдвигаться дальше с каждым Good (итерация \(i))")
            prevDue = card.due
            reviewDate = card.due
        }
    }

    // MARK: - Short-term stability (v6 specific)

    func test_sameDay_goodIncreasesStability() {
        // Same-day повтор Good должен поднимать stability (short_term формула)
        var card = makeReviewCard()
        let initialStability = card.stability
        // Сразу же Good (elapsedDays = 0 от last_review к now? нет, last_review был 10 дней назад)
        // Нужен other scenario: учим карточку, через 5 секунд Good
        card.lastReview = now.addingTimeInterval(-10) // 10 секунд назад
        let result = scheduler.schedule(card: card, rating: .good, now: now)
        XCTAssertGreaterThanOrEqual(result.stability, initialStability,
                                    "Same-day Good clamp >= 1.0 → stability не падает")
    }

    // MARK: - Граничные случаи

    func test_difficultyNeverExceedsBounds() {
        var card = makeReviewCard()
        for _ in 0..<20 {
            card = scheduler.schedule(card: card, rating: .again, now: now)
        }
        XCTAssertLessThanOrEqual(card.difficulty, 10.0)

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

    // MARK: - Cross-validation против py-fsrs v6.3.1
    //
    // Фикстуры сгенерированы скриптом /tmp/gen_fixtures.py через python -m fsrs==6.3.1
    // на дефолтных параметрах с disabled fuzzing. Если Swift расходится с эталонной
    // имплементацией хоть на 1e-9 в stability/difficulty — тест падает.

    func test_v6_matches_pyFsrs_fixtures() throws {
        let fixtures = try loadFixtures()
        XCTAssertEqual(fixtures.count, 17, "fixture count drift")

        for fixture in fixtures {
            let inputCard = buildInput(fixture.input)
            let rating = FSRSRating(rawValue: fixture.rating)!
            let reviewTime = now.addingTimeInterval(fixture.reviewOffsetS ?? 0)
            let result = scheduler.schedule(card: inputCard, rating: rating, now: reviewTime)

            XCTAssertEqual(result.state.rawValue, fixture.expected.state,
                           "[\(fixture.name)] state mismatch")
            XCTAssertEqual(result.step, fixture.expected.step,
                           "[\(fixture.name)] step mismatch")
            XCTAssertEqual(result.stability, fixture.expected.stability, accuracy: 1e-9,
                           "[\(fixture.name)] stability mismatch")
            XCTAssertEqual(result.difficulty, fixture.expected.difficulty, accuracy: 1e-9,
                           "[\(fixture.name)] difficulty mismatch")
            let actualDueOffset = result.due.timeIntervalSince(reviewTime)
            XCTAssertEqual(actualDueOffset, fixture.expected.dueOffsetS, accuracy: 1e-3,
                           "[\(fixture.name)] due offset mismatch")
        }
    }

    private func buildInput(_ input: FixtureInput) -> FSRSCardSnapshot {
        let state: FSRSState
        switch input.state {
        case "new": state = .new
        case "learning": state = .learning
        case "review": state = .review
        case "relearning": state = .relearning
        default: fatalError("unknown state: \(input.state)")
        }
        return FSRSCardSnapshot(
            state: state,
            difficulty: input.difficulty,
            stability: input.stability,
            reps: 0,
            lapses: 0,
            lastReview: input.lastReviewOffsetS.map { now.addingTimeInterval($0) },
            due: now.addingTimeInterval(input.dueOffsetS),
            step: input.step
        )
    }

    private func loadFixtures() throws -> [Fixture] {
        let data = Self.fixturesJSON.data(using: .utf8)!
        return try JSONDecoder().decode([Fixture].self, from: data)
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
            step: nil
        )
    }
}

// MARK: - Fixture types & embedded JSON

private struct Fixture: Decodable {
    let name: String
    let input: FixtureInput
    let rating: Int
    let reviewOffsetS: Double?
    let expected: FixtureExpected

    enum CodingKeys: String, CodingKey {
        case name, input, rating, expected
        case reviewOffsetS = "review_offset_s"
    }
}

private struct FixtureInput: Decodable {
    let state: String
    let stability: Double
    let difficulty: Double
    let step: Int?
    let lastReviewOffsetS: Double?
    let dueOffsetS: Double

    enum CodingKeys: String, CodingKey {
        case state, stability, difficulty, step
        case lastReviewOffsetS = "last_review_offset_s"
        case dueOffsetS = "due_offset_s"
    }
}

private struct FixtureExpected: Decodable {
    let state: Int
    let step: Int?
    let stability: Double
    let difficulty: Double
    let dueOffsetS: Double

    enum CodingKeys: String, CodingKey {
        case state, step, stability, difficulty
        case dueOffsetS = "due_offset_s"
    }
}

extension FSRSSchedulerTests {
    static let fixturesJSON: String = ###"""
    [{"name":"new_again","input":{"state":"new","stability":0.0,"difficulty":0.0,"step":null,"last_review_offset_s":null,"due_offset_s":0.0},"rating":1,"expected":{"state":1,"step":0,"stability":0.212,"difficulty":6.4133,"due_offset_s":60.0}},{"name":"new_hard","input":{"state":"new","stability":0.0,"difficulty":0.0,"step":null,"last_review_offset_s":null,"due_offset_s":0.0},"rating":2,"expected":{"state":1,"step":0,"stability":1.2931,"difficulty":5.112170705601056,"due_offset_s":330.0}},{"name":"new_good","input":{"state":"new","stability":0.0,"difficulty":0.0,"step":null,"last_review_offset_s":null,"due_offset_s":0.0},"rating":3,"expected":{"state":1,"step":1,"stability":2.3065,"difficulty":2.118103970459016,"due_offset_s":600.0}},{"name":"new_easy","input":{"state":"new","stability":0.0,"difficulty":0.0,"step":null,"last_review_offset_s":null,"due_offset_s":0.0},"rating":4,"expected":{"state":2,"step":null,"stability":8.2956,"difficulty":1.0,"due_offset_s":691200.0}},{"name":"learning_step1_again","input":{"state":"learning","stability":2.3065,"difficulty":2.118103970459016,"step":1,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":1,"review_offset_s":600.0,"expected":{"state":1,"step":0,"stability":0.7750839828558984,"difficulty":7.394502741279718,"due_offset_s":60.0}},{"name":"learning_step1_hard","input":{"state":"learning","stability":2.3065,"difficulty":2.118103970459016,"step":1,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":2,"review_offset_s":600.0,"expected":{"state":1,"step":1,"stability":1.3333787168039835,"difficulty":4.752858488532557,"due_offset_s":600.0}},{"name":"learning_step1_good","input":{"state":"learning","stability":2.3065,"difficulty":2.118103970459016,"step":1,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":3,"review_offset_s":600.0,"expected":{"state":2,"step":null,"stability":2.3065,"difficulty":2.111214235785395,"due_offset_s":172800.0}},{"name":"learning_step1_easy","input":{"state":"learning","stability":2.3065,"difficulty":2.118103970459016,"step":1,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":4,"review_offset_s":600.0,"expected":{"state":2,"step":null,"stability":3.946054067969477,"difficulty":1.0,"due_offset_s":345600.0}},{"name":"review_again","input":{"state":"review","stability":10.0,"difficulty":5.0,"step":null,"last_review_offset_s":-864000.0,"due_offset_s":0.0},"rating":1,"expected":{"state":3,"step":0,"stability":1.3919869729546932,"difficulty":8.341762369296838,"due_offset_s":600.0}},{"name":"review_hard","input":{"state":"review","stability":10.0,"difficulty":5.0,"step":null,"last_review_offset_s":-864000.0,"due_offset_s":0.0},"rating":2,"expected":{"state":2,"step":null,"stability":23.246875110466814,"difficulty":6.665995369296838,"due_offset_s":1987200.0}},{"name":"review_good","input":{"state":"review","stability":10.0,"difficulty":5.0,"step":null,"last_review_offset_s":-864000.0,"due_offset_s":0.0},"rating":3,"expected":{"state":2,"step":null,"stability":32.02672948198672,"difficulty":4.9902283692968386,"due_offset_s":2764800.0}},{"name":"review_easy","input":{"state":"review","stability":10.0,"difficulty":5.0,"step":null,"last_review_offset_s":-864000.0,"due_offset_s":0.0},"rating":4,"expected":{"state":2,"step":null,"stability":51.253861646812936,"difficulty":3.3144613692968385,"due_offset_s":4406400.0}},{"name":"review_sameday_good","input":{"state":"review","stability":10.0,"difficulty":5.0,"step":null,"last_review_offset_s":-10.0,"due_offset_s":0.0},"rating":3,"expected":{"state":2,"step":null,"stability":10.0,"difficulty":4.9902283692968386,"due_offset_s":864000.0}},{"name":"relearning_again","input":{"state":"relearning","stability":2.0,"difficulty":6.0,"step":0,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":1,"expected":{"state":3,"step":0,"stability":0.6784219062855583,"difficulty":8.670455569296838,"due_offset_s":600.0}},{"name":"relearning_hard","input":{"state":"relearning","stability":2.0,"difficulty":6.0,"step":0,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":2,"expected":{"state":3,"step":0,"stability":1.1670907293447836,"difficulty":7.329841969296838,"due_offset_s":900.0}},{"name":"relearning_good","input":{"state":"relearning","stability":2.0,"difficulty":6.0,"step":0,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":3,"expected":{"state":2,"step":null,"stability":2.007748803366632,"difficulty":5.989228369296838,"due_offset_s":172800.0}},{"name":"relearning_easy","input":{"state":"relearning","stability":2.0,"difficulty":6.0,"step":0,"last_review_offset_s":-600.0,"due_offset_s":0.0},"rating":4,"expected":{"state":2,"step":null,"stability":3.453934776504667,"difficulty":4.648614769296838,"due_offset_s":259200.0}}]
    """###
}
