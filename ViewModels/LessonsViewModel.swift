import SwiftUI
import Combine

struct CategoryStat: Identifiable, Equatable {
    let id: String
    let name: String
    let totalWords: Int
    let learnedWords: Int
    let icon: String
    let color: Color
    
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(learnedWords) / Double(totalWords)
    }
}

struct GrammarGroupUI: Identifiable, Hashable {
    let id: String
    let level: String
    let title: String
    let subtitle: String
    let iconText: String?
    let iconSymbol: String?
    let color: Color
    let isExam: Bool
}

final class LessonsViewModel: ObservableObject {
    @Published var categories: [CategoryStat] = []
    @Published var grammarLessons: [GrammarLesson] = []
    @Published var searchText: String = ""
    @Published var isEditMode: Bool = false
    
    @Published var selectedCategories: Set<String> = []
    @Published var completedGrammarLessons: Set<String> = []
    
    private let storageKey = "homeCategories"
    private let grammarCompletedKey = "completedGrammarLessons"
    
    init() {
        loadSelectedCategories()
        loadCompletedGrammar()
    }
    
    var filteredCategories: [CategoryStat] {
        if searchText.isEmpty { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var searchResultsGrammar: [GrammarLesson] {
        guard !searchText.isEmpty else { return [] }
        return grammarLessons.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var grammarGroups: [GrammarGroupUI] {
        var groups: [GrammarGroupUI] = []
        let levelConfigs: [(id: String, sub: String, color: Color)] = [
            ("A0", "Введение", .teal),
            ("A1", "Основы", .green),
            ("A2", "Базовый", .blue),
            ("B1", "Средний", .orange),
            ("B2", "Продвинутый", .purple)
        ]
        
        for config in levelConfigs {
            let count = grammarLessons.filter { $0.level == config.id }.count
            if count > 0 {
                groups.append(GrammarGroupUI(
                    id: config.id, level: config.id, title: "Уровень \(config.id)", subtitle: config.sub,
                    iconText: config.id, iconSymbol: nil, color: config.color, isExam: false
                ))
            }
        }
        
        let examCount = grammarLessons.filter { $0.level == "B1_Exam" }.count
        if examCount > 0 {
            groups.append(GrammarGroupUI(
                id: "B1_Exam", level: "B1_Exam", title: "Экзамен B1", subtitle: "Подготовка к сертификации",
                iconText: nil, iconSymbol: "graduationcap.fill", color: .red, isExam: true
            ))
        }
        
        return groups
    }
    
    func lessons(for groupId: String) -> [GrammarLesson] {
        grammarLessons.filter { $0.level == groupId }
    }
    
    func loadData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let allWords = DataLoader.shared.loadWords()
            let grammar = DataLoader.shared.loadGrammar()
            
            var stats: [String: (total: Int, learned: Int)] = [:]
            for word in allWords {
                stats[word.category, default: (0, 0)].total += 1
                if word.safeBox > 0 { stats[word.category, default: (0, 0)].learned += 1 }
            }
            
            let categoryStats = stats.map { (key, value) -> CategoryStat in
                let theme = self?.generateTheme(for: key)
                return CategoryStat(
                    id: key, name: key, totalWords: value.total, learnedWords: value.learned,
                    icon: theme?.icon ?? "folder.fill", color: theme?.color ?? .blue
                )
            }.sorted { $0.name < $1.name }
            
            DispatchQueue.main.async {
                self?.categories = categoryStats
                self?.grammarLessons = grammar
            }
        }
    }
    
    func toggleCategorySelection(_ categoryName: String) {
        if selectedCategories.contains(categoryName) { selectedCategories.remove(categoryName) }
        else { selectedCategories.insert(categoryName) }
        saveSelectedCategories()
    }
    
    private func loadSelectedCategories() {
        if let stringValue = UserDefaults.standard.string(forKey: storageKey),
           let data = stringValue.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.selectedCategories = Set(decoded)
        }
    }
    
    private func saveSelectedCategories() {
        if let data = try? JSONEncoder().encode(Array(selectedCategories)),
           let stringValue = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(stringValue, forKey: storageKey)
        }
    }
    
    func loadCompletedGrammar() {
        if let data = UserDefaults.standard.array(forKey: grammarCompletedKey) as? [String] {
            self.completedGrammarLessons = Set(data)
        }
    }
    
    private func generateTheme(for category: String) -> (icon: String, color: Color) {
        let hash = category.hashValue
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill", "message.fill", "house.fill"]
        return (icons[abs(hash) % icons.count], colors[abs(hash) % colors.count])
    }
}
