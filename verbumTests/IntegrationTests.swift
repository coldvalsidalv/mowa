import Testing
import Foundation
import SwiftData
@testable import Verbum

/// Интеграционные тесты на Swift Testing (`@Test`), а не XCTest.
///
/// Зачем отдельный фреймворк: XCTest под Swift 6 default-MainActor isolation
/// крашит runtime при освобождении `ProfileViewModel`/`LessonsViewModel`
/// (`BUG_IN_CLIENT_OF_LIBMALLOC` в `swift_task_deinitOnExecutorImpl`).
/// Swift Testing корректно работает с isolated deinit — `@MainActor`
/// на тесте/suite держит весь жизненный цикл инстанса на main, и release
/// объекта проходит без хопа на чужой executor.
///
/// **Правило проекта:** unit-тесты на чистые функции — XCTest (см.
/// LessonsViewModelTests, ProfileViewModelTests). Тесты, требующие
/// инстанс VM или ModelContainer — Swift Testing, как здесь.

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

    /// Ждём пока `vm.categories` станет непустым (loadCategories асинхронна).
    /// Поллим, потому что @Published.sink + confirmation усложняет тест без выгоды.
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
        // Главное что проверяем — что vm уйдёт из scope в конце test и
        // его deinit отработает без libmalloc-краша. Под XCTest этот же
        // сценарий валит runtime; под Swift Testing — должен пройти.
        let container = try makeContainer()
        let ctx = ModelContext(container)
        ctx.insert(makeWord("X"))
        try ctx.save()

        do {
            let vm = LessonsViewModel()
            vm.loadCategories(container: container)
            await waitForCategories(vm)
            #expect(vm.categories.count == 1)
        } // vm.deinit здесь
    }

    @Test("empty database yields empty categories")
    func emptyDB() async throws {
        let container = try makeContainer()
        let vm = LessonsViewModel()

        vm.loadCategories(container: container)

        // Дожидаемся завершения Task.detached даже если он ничего не публикует.
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
