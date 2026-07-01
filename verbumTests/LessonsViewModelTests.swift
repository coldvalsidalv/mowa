import XCTest
import SwiftData
@testable import Verbum

/// Tests of the pure category-grouping logic.
/// We don't do an integration test with a real LessonsViewModel + ModelContainer —
/// under Swift 6 isolated-deinit, XCTest crashes the runtime when the VM is released.
/// A pure static func gives determinism and doesn't depend on async/actor infrastructure.
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
        // "Learned" in this UI = "no longer .new" (learning/review/relearning).
        // This is consistent with card progress on the "Learn" screen.
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
        // The icon must not "jump" between runs — a UX invariant.
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
