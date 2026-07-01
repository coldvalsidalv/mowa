import Testing
import Foundation
import SwiftData
@testable import Verbum

/// Integration tests on Swift Testing (`@Test`), not XCTest.
///
/// Why a separate framework: under Swift 6 default-MainActor isolation, XCTest
/// crashes the runtime when releasing `ProfileViewModel`/`LessonsViewModel`
/// (`BUG_IN_CLIENT_OF_LIBMALLOC` in `swift_task_deinitOnExecutorImpl`).
/// Swift Testing handles isolated deinit correctly — `@MainActor` on the
/// test/suite keeps the whole instance lifecycle on main, and the object's
/// release happens without a hop to a foreign executor.
///
/// **Project rule:** unit tests for pure functions — XCTest (see
/// LessonsViewModelTests, ProfileViewModelTests). Tests that need a
/// VM instance or a ModelContainer — Swift Testing, like here.

// MARK: - LessonsViewModel.loadCategories

@Suite("LessonsViewModel — loadCategories integration")
@MainActor
struct LessonsViewModelIntegration {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: VocabItem.self, ReviewLog.self, GrammarProgress.self,
            configurations: config
        )
    }

    private func makeWord(_ category: String, state: FSRSState = .new) -> VocabItem {
        let w = VocabItem(
            polish: "p_\(UUID().uuidString.prefix(6))",
            translation: "t", partOfSpeech: "n", example: "—",
            category: category
        )
        w.fsrsData.state = state
        return w
    }

    /// Wait until `vm.categories` becomes non-empty (loadCategories is async).
    /// We poll because @Published.sink + confirmation complicates the test with no benefit.
    private func waitForCategories(_ vm: LessonsViewModel, timeoutMs: Int = 3000) async {
        let stepMs = 50
        for _ in 0..<(timeoutMs / stepMs) {
            if !vm.categories.isEmpty { return }
            try? await Task.sleep(for: .milliseconds(stepMs))
        }
    }

    @Test("populates categories from background context")
    func populatesCategories() async throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        ctx.insert(makeWord("Cat1"))
        ctx.insert(makeWord("Cat1", state: .review))
        ctx.insert(makeWord("Cat2", state: .review))
        try ctx.save()

        let vm = LessonsViewModel()
        #expect(vm.categories.isEmpty)

        vm.loadCategories(container: container)
        await waitForCategories(vm)

        #expect(vm.categories.count == 2)
        let cat1 = vm.categories.first { $0.id == "Cat1" }
        #expect(cat1?.totalWords == 2)
        #expect(cat1?.learnedWords == 1)
    }

    @Test("loadCategories survives VM release without isolated-deinit crash")
    func vmReleaseNoCrash() async throws {
        // The key thing we check — that the vm leaves scope at the end of the test and
        // its deinit runs without a libmalloc crash. Under XCTest this same
        // scenario crashes the runtime; under Swift Testing it should pass.
        let container = try makeContainer()
        let ctx = ModelContext(container)
        ctx.insert(makeWord("X"))
        try ctx.save()

        do {
            let vm = LessonsViewModel()
            vm.loadCategories(container: container)
            await waitForCategories(vm)
            #expect(vm.categories.count == 1)
        } // vm.deinit here
    }

    @Test("empty database yields empty categories")
    func emptyDB() async throws {
        let container = try makeContainer()
        let vm = LessonsViewModel()

        vm.loadCategories(container: container)

        // Wait for the Task.detached to finish even if it publishes nothing.
        try await Task.sleep(for: .milliseconds(300))
        #expect(vm.categories.isEmpty)
    }
}

// MARK: - ProfileViewModel.loadStats

@Suite("ProfileViewModel — loadStats integration")
@MainActor
struct ProfileViewModelIntegration {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: VocabItem.self, ReviewLog.self, GrammarProgress.self,
            configurations: config
        )
    }

    private func makeWord(stability: Double) -> VocabItem {
        let w = VocabItem(polish: "p", translation: "t", partOfSpeech: "n", example: "—", category: "c")
        w.fsrsData.stability = stability
        return w
    }

    @Test("counts words with stability >= 3 days threshold")
    func stabilityThreshold() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        for s in [0.5, 2.9, 3.0, 10.0, 50.0] {
            ctx.insert(makeWord(stability: s))
        }
        try ctx.save()

        let vm = ProfileViewModel()
        vm.loadStats(context: ctx)

        #expect(vm.totalLearnedWords == 3, "stability >= 3.0 → 3 of 5 words")
    }

    @Test("loadStats triggers recomputeAchievements")
    func loadStatsRecomputes() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        ctx.insert(makeWord(stability: 10))
        try ctx.save()

        let vm = ProfileViewModel()
        #expect(vm.achievements.first { $0.title == "Первое слово" }?.unlocked == false)

        vm.loadStats(context: ctx)

        #expect(vm.totalLearnedWords == 1)
        #expect(vm.achievements.first { $0.title == "Первое слово" }?.unlocked == true,
                "loadStats должен дёрнуть recomputeAchievements (контракт из ProfileViewModel.swift)")
    }
}
