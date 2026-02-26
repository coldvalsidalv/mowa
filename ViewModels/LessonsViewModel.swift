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
    
    /// Загрузка данных теперь требует ModelContext для прямого доступа к базе
    func loadData(context: ModelContext) {
        // 1. Выборка слов из SwiftData
        let descriptor = FetchDescriptor<VocabItem>()
        let words = (try? context.fetch(descriptor)) ?? []
        
        // 2. Чтение грамматики из статического JSON через обновленный DataManager
        let rawLessons = DataManager.shared.loadGrammar()
        let completedIDs = Set(UserDefaults.standard.stringArray(forKey: StorageKeys.completedGrammarLessons) ?? [])
        
        // 3. Синхронный расчет статистики категорий
        let uniqueCategories = Array(Set(words.map { $0.category })).sorted()
        self.categories = uniqueCategories.map { category in
            let categoryWords = words.filter { $0.category == category }
            // В FSRS слово считается начатым/выученным, если его состояние отлично от .new
            let learned = categoryWords.filter { $0.fsrsData.state != .new }.count
            let theme = Self.getTheme(for: category)
            return CategoryStat(id: category, totalWords: categoryWords.count, learnedWords: learned, icon: theme.icon, color: theme.color)
        }
        
        // 4. Расчет статистики грамматики
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
        
        // Добавление экзамена B1
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
    
    private static func getTheme(for category: String) -> (icon: String, color: Color) {
        let hash = category.hashValue
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill"]
        return (icons[abs(hash) % icons.count], colors[abs(hash) % colors.count])
    }
    
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
