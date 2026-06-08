import XCTest
import SwiftData
@testable import Verbum

/// Тесты pure-логики группировки слов в категории.
/// Integration-тест с реальным LessonsViewModel + ModelContainer не делаем —
/// под Swift 6 isolated-deinit XCTest крашит runtime при освобождении VM.
/// Pure static func даёт детерминизм и не зависит от async/actor-инфраструктуры.
final class LessonsViewModelTests: XCTestCase {

    private func makeWord(category: String, state: FSRSState = .new) -> VocabItem {
        let w = VocabItem(
            polish: "test_\(UUID().uuidString.prefix(6))",
            translation: "тест",
            partOfSpeech: "noun",
            example: "—",
            category: category
        )
        w.fsrsData.state = state
        return w
    }

    // MARK: - computeCategories

    func test_emptyInput_returnsEmpty() {
        XCTAssertTrue(LessonsViewModel.computeCategories(from: []).isEmpty)
    }

    func test_groupsByCategoryName() {
        let words = [
            makeWord(category: "Еда"),
            makeWord(category: "Еда"),
            makeWord(category: "Дом"),
        ]
        let result = LessonsViewModel.computeCategories(from: words)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first { $0.id == "Еда" }?.totalWords, 2)
        XCTAssertEqual(result.first { $0.id == "Дом" }?.totalWords, 1)
    }

    func test_learnedCount_isStateNotNew() {
        // "Выучено" в этом UI = "уже не .new" (learning/review/relearning).
        // Это согласовано с card progress на экране "Учить".
        let words = [
            makeWord(category: "X", state: .new),
            makeWord(category: "X", state: .learning),
            makeWord(category: "X", state: .review),
            makeWord(category: "X", state: .relearning),
        ]
        let stat = LessonsViewModel.computeCategories(from: words).first!
        XCTAssertEqual(stat.totalWords, 4)
        XCTAssertEqual(stat.learnedWords, 3, "Только .new не считаются")
    }

    func test_sortsAlphabetically() {
        let result = LessonsViewModel.computeCategories(from: [
            makeWord(category: "Zoo"),
            makeWord(category: "Apple"),
            makeWord(category: "Music"),
        ])
        XCTAssertEqual(result.map(\.id), ["Apple", "Music", "Zoo"])
    }

    func test_consistentIconAndColorAcrossRuns() {
        // Иконка не должна "прыгать" между запусками — UX-инвариант.
        let a = LessonsViewModel.computeCategories(from: [makeWord(category: "Стабильность")])
        let b = LessonsViewModel.computeCategories(from: [makeWord(category: "Стабильность")])
        XCTAssertEqual(a[0].icon, b[0].icon)
    }

    func test_progressZeroWhenNothingLearned() {
        let words = [makeWord(category: "X"), makeWord(category: "X")]
        XCTAssertEqual(LessonsViewModel.computeCategories(from: words)[0].progress, 0.0)
    }

    func test_progressOneWhenAllLearned() {
        let words = [
            makeWord(category: "X", state: .review),
            makeWord(category: "X", state: .review),
        ]
        XCTAssertEqual(LessonsViewModel.computeCategories(from: words)[0].progress, 1.0)
    }

    func test_halfProgress() {
        let words = [
            makeWord(category: "X", state: .review),
            makeWord(category: "X", state: .new),
        ]
        XCTAssertEqual(LessonsViewModel.computeCategories(from: words)[0].progress, 0.5)
    }
}
