import SwiftUI
import SwiftData
import Combine

struct CategoryStat: Identifiable {
    let id: String
    var name: String { id }
    let totalWords: Int
    let learnedWords: Int
    let icon: String
    let color: Color
    var progress: Double { totalWords > 0 ? Double(learnedWords) / Double(totalWords) : 0 }
}

struct GrammarGroupUI: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let iconText: String?
    let iconSymbol: String?
    let color: Color
    let isExam: Bool
    let totalLessons: Int
    let completedLessons: Int
    var progress: Double { totalLessons > 0 ? Double(completedLessons) / Double(totalLessons) : 0 }
}

@MainActor
final class LessonsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isEditMode = false
    
    @Published var categories: [CategoryStat] = []
    @Published var grammarGroups: [GrammarGroupUI] = []
    @Published var allGrammarLessons: [GrammarLesson] = []
    @Published var completedGrammarLessonIDs: Set<String> = []
    
    @AppStorage(StorageKeys.homeCategories) private var storage: CategoryStorage = CategoryStorage()
    
    var selectedCategories: [String] {
        storage.items
    }
    
    var filteredCategories: [CategoryStat] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    /// Загружает грамматику: парс бандла на фоновом потоке, API обновляет в фоне
    func loadGrammar() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let bundleLessons = DataManager.shared.loadGrammar()
            await self?.updateGrammar(from: bundleLessons)

            do {
                let apiLessons = try await APIClient.shared.fetchAllGrammarLessons()
                if !apiLessons.isEmpty {
                    await self?.updateGrammar(from: apiLessons)
                }
            } catch {}
        }
    }

    /// Загружает категории на background ModelContext, чтобы не материализовать
    /// 500 VocabItem на main thread (раньше @Query в LessonsView давал ~1s фриз).
    func loadCategories(container: ModelContainer) {
        Task.detached(priority: .userInitiated) {
            var descriptor = FetchDescriptor<VocabItem>()
            descriptor.relationshipKeyPathsForPrefetching = [\.fsrsData]
            let bg = ModelContext(container)
            let words = (try? bg.fetch(descriptor)) ?? []
            let stats = Self.computeCategories(from: words)
            await MainActor.run { [weak self] in
                self?.categories = stats
            }
        }
    }

    /// Чистая функция, считается на background — никаких обращений к UI.
    /// Internal вместо private — чтобы покрыть тестами без хрупкой async-инфраструктуры.
    nonisolated static func computeCategories(from words: [VocabItem]) -> [CategoryStat] {
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill"]
        let grouped = Dictionary(grouping: words, by: \.category)
        return grouped.keys.sorted().map { category in
            let items = grouped[category]!
            let learned = items.filter { $0.fsrsData.state != .new }.count
            let hash = category.stableHash
            return CategoryStat(
                id: category,
                totalWords: items.count,
                learnedWords: learned,
                icon: icons[hash % icons.count],
                color: colors[hash % colors.count]
            )
        }
    }

    private func updateGrammar(from rawLessons: [GrammarLesson]) {
        let completedIDs = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.completedGrammarLessons) ?? [])

        let levels = ["A0", "A1", "A2", "B1", "B2"]
        var groups: [GrammarGroupUI] = levels.map { level in
            let levelLessons = rawLessons.filter { $0.level == level }
            let completedCount = levelLessons.filter { completedIDs.contains($0.id) }.count
            return GrammarGroupUI(
                id: level,
                title: "Уровень \(level)",
                subtitle: Self.getDescription(for: level),
                iconText: level,
                iconSymbol: nil,
                color: Self.getColor(for: level),
                isExam: false,
                totalLessons: levelLessons.count,
                completedLessons: completedCount
            )
        }

        let examLessons = rawLessons.filter { $0.level == "B1_Exam" }
        let examCompleted = examLessons.filter { completedIDs.contains($0.id) }.count
        groups.append(GrammarGroupUI(
            id: "B1_Exam",
            title: "Экзамен B1",
            subtitle: "Подготовка к сертификации",
            iconText: nil,
            iconSymbol: "graduationcap.fill",
            color: .red,
            isExam: true,
            totalLessons: examLessons.count,
            completedLessons: examCompleted
        ))

        self.allGrammarLessons = rawLessons
        self.completedGrammarLessonIDs = completedIDs
        self.grammarGroups = groups.filter { $0.totalLessons > 0 }
    }
    
    func toggleCategorySelection(_ category: String) {
        if storage.items.contains(category) {
            storage.items.removeAll { $0 == category }
        } else {
            storage.items.append(category)
        }
    }
    
    func lessons(for groupID: String) -> [GrammarLesson] {
        allGrammarLessons.filter { $0.level == groupID }
    }
    
    // MARK: - Вспомогательные статические методы

    private static func getColor(for level: String) -> Color {
        switch level {
        case "A0", "A1": return .green
        case "A2": return .blue
        case "B1": return .orange
        case "B2": return .purple
        default: return .gray
        }
    }
    
    private static func getDescription(for level: String) -> String {
        switch level {
        case "A0": return "Введение"
        case "A1": return "Основы"
        case "A2": return "Базовый"
        case "B1": return "Средний"
        case "B2": return "Продвинутый"
        default: return ""
        }
    }
}
