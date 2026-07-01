import XCTest
@testable import Verbum

/// Тесты pure-логики достижений.
/// Создание ProfileViewModel в XCTest под Swift 6 isolated-deinit крашит runtime
/// (BUG_IN_CLIENT_OF_LIBMALLOC при swift_task_deinitOnExecutorImpl), поэтому
/// проверяем фабрику напрямую — это и так чище: pure → детерминизм.
final class ProfileViewModelTests: XCTestCase {

    private func make(words: Int = 0, streak: Int = 0, xp: Int = 0, grammar: Int = 0, totalGrammarLessons: Int = 6) -> [Achievement] {
        ProfileViewModel.makeAchievements(
            totalLearnedWords: words,
            dayStreak: streak,
            userXP: xp,
            grammar: grammar,
            totalGrammarLessons: totalGrammarLessons
        )
    }

    // MARK: - Базовые инварианты

    func test_zeroProgress_allAchievementsLocked() {
        let all = make()
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(all.allSatisfy { !$0.unlocked })
        XCTAssertTrue(all.allSatisfy { $0.progress == 0.0 })
    }

    func test_progressNeverExceedsOne() {
        let all = make(words: 99_999, streak: 999, xp: 999_999, grammar: 999)
        for a in all {
            XCTAssertLessThanOrEqual(a.progress, 1.0, "\(a.title) = \(a.progress)")
            XCTAssertGreaterThanOrEqual(a.progress, 0.0)
        }
    }

    func test_extremeValues_allUnlocked() {
        let all = make(words: 99_999, streak: 999, xp: 999_999, grammar: 999)
        XCTAssertTrue(all.allSatisfy { $0.unlocked })
    }

    // MARK: - Пороги по словам

    func test_firstWord_unlocksAt1() {
        XCTAssertFalse(make(words: 0).first { $0.title == "Первое слово" }!.unlocked)
        XCTAssertTrue(make(words: 1).first { $0.title == "Первое слово" }!.unlocked)
    }

    func test_wordThresholds_unlockInOrder() {
        let cases: [(Int, [String], [String])] = [
            (9,    ["Первое слово"],
                   ["Десятка", "Сотня", "Полиглот", "Мастер слов"]),
            (10,   ["Первое слово", "Десятка"],
                   ["Сотня", "Полиглот", "Мастер слов"]),
            (100,  ["Первое слово", "Десятка", "Сотня"],
                   ["Полиглот", "Мастер слов"]),
            (500,  ["Первое слово", "Десятка", "Сотня", "Полиглот"],
                   ["Мастер слов"]),
            (2000, ["Первое слово", "Десятка", "Сотня", "Полиглот", "Мастер слов"], []),
        ]
        for (words, unlocked, locked) in cases {
            let all = make(words: words)
            for t in unlocked {
                XCTAssertTrue(all.first { $0.title == t }!.unlocked, "\(words) слов → \(t) должно быть unlocked")
            }
            for t in locked {
                XCTAssertFalse(all.first { $0.title == t }!.unlocked, "\(words) слов → \(t) должно быть locked")
            }
        }
    }

    // MARK: - Пороги по XP

    func test_xpThresholds() {
        let all1k = make(xp: 1000)
        XCTAssertTrue(all1k.first { $0.title == "Первые очки" }!.unlocked)
        XCTAssertTrue(all1k.first { $0.title == "Чемпион" }!.unlocked)
        XCTAssertFalse(all1k.first { $0.title == "Легенда" }!.unlocked)

        XCTAssertTrue(make(xp: 5000).first { $0.title == "Легенда" }!.unlocked)
    }

    // MARK: - Пороги по streak

    func test_streakThresholds() {
        let all7 = make(streak: 7)
        XCTAssertTrue(all7.first { $0.title == "Привычка" }!.unlocked)
        XCTAssertTrue(all7.first { $0.title == "Огонь" }!.unlocked)
        XCTAssertFalse(all7.first { $0.title == "Несгораемый" }!.unlocked)

        XCTAssertTrue(make(streak: 30).first { $0.title == "Несгораемый" }!.unlocked)
    }

    // MARK: - Грамматика

    func test_grammarThresholds() {
        XCTAssertTrue(make(grammar: 1).first { $0.title == "Первый урок" }!.unlocked)
        XCTAssertTrue(make(grammar: 5).first { $0.title == "Грамматик" }!.unlocked)
        XCTAssertFalse(make(grammar: 5, totalGrammarLessons: 6).first { $0.title == "Профессор" }!.unlocked)
        XCTAssertTrue(make(grammar: 6, totalGrammarLessons: 6).first { $0.title == "Профессор" }!.unlocked)
    }

    /// "Профессор" threshold tracks the actual lesson count, not a magic constant.
    func test_professorAchievement_tracksActualLessonCount() {
        XCTAssertFalse(make(grammar: 6, totalGrammarLessons: 10).first { $0.title == "Профессор" }!.unlocked)
        XCTAssertTrue(make(grammar: 10, totalGrammarLessons: 10).first { $0.title == "Профессор" }!.unlocked)
    }

    // MARK: - Композитная ачивка "Разносторонний"

    func test_composite_requiresBothWordsAndGrammar() {
        // Только слова — закрыто
        XCTAssertFalse(make(words: 50, grammar: 2).first { $0.title == "Разносторонний" }!.unlocked)
        // Только грамматика — закрыто
        XCTAssertFalse(make(words: 49, grammar: 3).first { $0.title == "Разносторонний" }!.unlocked)
        // Оба порога — открыто
        XCTAssertTrue(make(words: 50, grammar: 3).first { $0.title == "Разносторонний" }!.unlocked)
    }
}
