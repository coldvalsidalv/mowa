import SwiftUI

// --- ОСНОВНОЙ ЭКРАН ---
struct LessonsView: View {
<<<<<<< Updated upstream
    @State private var selectedTab = 0 // 0 = Слова, 1 = Грамматика
    @State private var searchText = ""
    @State private var isEditMode = false
    
    @State private var allWords: [WordItem] = []
    @State private var categories: [String] = []
    @State private var grammarLessons: [GrammarLesson] = []
    
    @AppStorage(StorageKeys.homeCategories) private var storage: CategoryStorage = CategoryStorage()
    
    var filteredCategories: [String] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
=======
    @StateObject private var viewModel = LessonsViewModel()
    @State private var selectedTab = 0 // 0 = Слова, 1 = Грамматика
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
    
    let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        pickerView
                        searchBar
                    }
                    .padding(.bottom, 10)
                    .background(Color(UIColor.systemGroupedBackground))
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
<<<<<<< Updated upstream
<<<<<<< Updated upstream
                                if categories.isEmpty {
                                    if allWords.isEmpty { loadingView }
                                    else { Text("Нет категорий").foregroundColor(.gray) }
=======
                                if viewModel.categories.isEmpty {
                                    loadingView
>>>>>>> Stashed changes
=======
                                if viewModel.categories.isEmpty {
                                    loadingView
>>>>>>> Stashed changes
                                } else {
                                    wordsGridView
                                }
                            } else {
                                grammarLevelsView
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Библиотека")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
<<<<<<< Updated upstream
<<<<<<< Updated upstream
                                isEditMode.toggle()
=======
                                viewModel.isEditMode.toggle()
>>>>>>> Stashed changes
=======
                                viewModel.isEditMode.toggle()
>>>>>>> Stashed changes
                            }
                        }) {
                            Image(systemName: isEditMode ? "checkmark" : "pencil")
                                .font(.body.bold())
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
<<<<<<< Updated upstream
            .onAppear { loadData() }
        }
    }
    
    // --- UI КОМПОНЕНТЫ ---
    
    var pickerView: some View {
        Picker("Тип", selection: $selectedTab) {
            Text("Слова").tag(0)
            Text("Грамматика").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 10)
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 1 { isEditMode = false }
        }
    }
    
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(Color(UIColor.systemGray))
            TextField("Поиск...", text: $searchText)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.systemGray2))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    var wordsGridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(filteredCategories, id: \.self) { category in
                let categoryWords = allWords.filter { $0.category == category }
                let totalCount = categoryWords.count
                let learnedCount = categoryWords.filter { $0.safeBox > 0 }.count
                let isSelected = storage.items.contains(category)
                
                if isEditMode {
                    CategoryCardView(category: category, totalWords: totalCount, learnedWords: learnedCount, isSelected: isSelected, isEditMode: true)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { toggleCategorySelection(category) }
                        }
                } else {
                    NavigationLink(destination: FlashcardView(categories: [category], isReviewMode: false)) {
                        CategoryCardView(category: category, totalWords: totalCount, learnedWords: learnedCount, isSelected: false, isEditMode: false)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // МЕНЮ УРОВНЕЙ ГРАММАТИКИ
    var grammarLevelsView: some View {
        LazyVStack(spacing: 16) {
            let levels = ["A0", "A1", "A2", "B1", "B2"]
            
            ForEach(levels, id: \.self) { level in
                let levelLessons = grammarLessons.filter { $0.level == level }
                
                NavigationLink(destination: GrammarLevelListView(title: "Уровень \(level)", lessons: levelLessons)) {
                    GrammarLevelCardView(level: level, lessonCount: levelLessons.count)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Экзамен B1 всегда внизу
            let examLessons = grammarLessons.filter { $0.level == "B1_Exam" }
            NavigationLink(destination: GrammarLevelListView(title: "Экзамен B1", lessons: examLessons)) {
                ExamLevelCardView(lessonCount: examLessons.count)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 8)
    }
    
    var loadingView: some View {
        VStack {
            ProgressView().scaleEffect(1.5).padding()
            Text("Загрузка контента...").foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    func loadData() {
        self.allWords = DataLoader.shared.loadWords()
        self.categories = Array(Set(self.allWords.map { $0.category })).sorted()
        self.grammarLessons = DataLoader.shared.loadGrammar()
    }
    
    func toggleCategorySelection(_ category: String) {
        if storage.items.contains(category) {
            storage.items.removeAll { $0 == category }
        } else {
            storage.items.append(category)
=======
            .onAppear { viewModel.loadData() }
        }
    }
    
    // MARK: - UI Компоненты
    
    private var pickerView: some View {
        Picker("Тип", selection: $selectedTab) {
            Text("Слова").tag(0)
            Text("Грамматика").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 10)
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 1 { viewModel.isEditMode = false }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(Color(UIColor.systemGray))
            TextField("Поиск...", text: $viewModel.searchText)
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.systemGray2))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var wordsGridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(viewModel.filteredCategories) { stat in
                let isSelected = viewModel.selectedCategories.contains(stat.id)
                
                if viewModel.isEditMode {
                    CategoryCardView(stat: stat, isSelected: isSelected, isEditMode: true)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleCategorySelection(stat.id)
                            }
                        }
                } else {
                    NavigationLink(destination: FlashcardView(categories: [stat.id], isReviewMode: false)) {
                        CategoryCardView(stat: stat, isSelected: false, isEditMode: false)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
        }
    }
    
    private var grammarLevelsView: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.grammarGroups) { group in
                let groupLessons = viewModel.lessons(for: group.id)
                
                NavigationLink(destination: GrammarLevelListView(title: group.title, lessons: groupLessons)) {
                    if group.isExam {
                        ExamLevelCardView(group: group, lessonCount: groupLessons.count)
                    } else {
                        GrammarLevelCardView(group: group, lessonCount: groupLessons.count)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView().scaleEffect(1.5).padding()
            Text("Загрузка контента...").foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

<<<<<<< Updated upstream
<<<<<<< Updated upstream
// --- СУБВЬЮ КАРТОЧКИ КАТЕГОРИИ (ОПТИМИЗИРОВАННАЯ ПЛИТКА) ---
=======
// MARK: - Карточка Категории Слов
>>>>>>> Stashed changes
=======
// MARK: - Карточка Категории Слов
>>>>>>> Stashed changes
struct CategoryCardView: View {
    let category: String
    let totalWords: Int
    let learnedWords: Int
    let isSelected: Bool
    let isEditMode: Bool
    
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(learnedWords) / Double(totalWords)
    }
    
    var theme: (icon: String, color: Color) {
        let hash = category.hashValue
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill"]
        return (icons[abs(hash) % icons.count], colors[abs(hash) % colors.count])
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
<<<<<<< Updated upstream
<<<<<<< Updated upstream
                    Circle().fill(theme.color.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: theme.icon).font(.title3).foregroundColor(theme.color)
=======
=======
>>>>>>> Stashed changes
                    Circle().fill(stat.color.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: stat.icon).font(.title3).foregroundColor(stat.color)
>>>>>>> Stashed changes
                }
                Spacer()
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            Spacer(minLength: 16)
            
            VStack(alignment: .leading, spacing: 8) {
<<<<<<< Updated upstream
<<<<<<< Updated upstream
                Text(category).font(.headline).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.8)
                
                VStack(spacing: 6) {
                    HStack {
                        Text("\(learnedWords)/\(totalWords) слов").font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(progress * 100))%").font(.caption).bold().foregroundColor(theme.color)
                    }
                    ProgressView(value: progress).tint(theme.color).scaleEffect(x: 1, y: 0.8, anchor: .center)
=======
                Text(stat.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                VStack(spacing: 6) {
                    HStack {
                        Text("\(stat.learnedWords)/\(stat.totalWords) слов").font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(stat.progress * 100))%").font(.caption).bold().foregroundColor(stat.color)
                    }
                    ProgressView(value: stat.progress)
                        .tint(stat.color)
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
>>>>>>> Stashed changes
=======
                Text(stat.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                VStack(spacing: 6) {
                    HStack {
                        Text("\(stat.learnedWords)/\(stat.totalWords) слов").font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(stat.progress * 100))%").font(.caption).bold().foregroundColor(stat.color)
                    }
                    ProgressView(value: stat.progress)
                        .tint(stat.color)
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
>>>>>>> Stashed changes
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(isSelected && isEditMode ? Color.blue.opacity(0.05) : Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected && isEditMode ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

<<<<<<< Updated upstream
<<<<<<< Updated upstream
// --- КАРТОЧКА УРОВНЯ ГРАММАТИКИ ---
struct GrammarLevelCardView: View {
    let level: String
=======
// MARK: - Карточка Уровня Грамматики
struct GrammarLevelCardView: View {
    let group: GrammarGroupUI
>>>>>>> Stashed changes
    let lessonCount: Int
    
    var levelColor: Color {
        switch level {
        case "A0", "A1": return .green
        case "A2": return .blue
        case "B1": return .orange
        case "B2": return .purple
        default: return .gray
        }
    }
    
    var levelDescription: String {
        switch level {
        case "A0": return "Введение"
        case "A1": return "Основы"
        case "A2": return "Базовый"
        case "B1": return "Средний"
        case "B2": return "Продвинутый"
        default: return ""
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(levelColor.opacity(0.15)).frame(width: 52, height: 52)
                Text(level).font(.headline).bold().foregroundColor(levelColor)
            }
            VStack(alignment: .leading, spacing: 4) {
<<<<<<< Updated upstream
                Text("Уровень \(level)").font(.headline).foregroundColor(.primary)
                Text(levelDescription).font(.subheadline).foregroundColor(.gray)
=======
                Text(group.title).font(.headline).foregroundColor(.primary)
                Text(group.subtitle).font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            Text("\(lessonCount) уроков")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.secondary)
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Карточка Экзамена B1
struct ExamLevelCardView: View {
=======
// MARK: - Карточка Уровня Грамматики
struct GrammarLevelCardView: View {
>>>>>>> Stashed changes
    let group: GrammarGroupUI
    let lessonCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(group.color.opacity(0.15)).frame(width: 52, height: 52)
                if let symbol = group.iconSymbol {
                    Image(systemName: symbol).font(.headline).foregroundColor(group.color)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title).font(.headline).foregroundColor(.primary)
                Text(group.subtitle).font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            Text("\(lessonCount) уроков")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.secondary)
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Карточка Экзамена B1
struct ExamLevelCardView: View {
    let group: GrammarGroupUI
    let lessonCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(group.color.opacity(0.15)).frame(width: 52, height: 52)
                if let symbol = group.iconSymbol {
                    Image(systemName: symbol).font(.headline).foregroundColor(group.color)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title).font(.headline).foregroundColor(.primary)
                Text(group.subtitle).font(.subheadline).foregroundColor(.gray).lineLimit(1)
>>>>>>> Stashed changes
            }
            Spacer()
            Text("\(lessonCount) уроков")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
<<<<<<< Updated upstream
<<<<<<< Updated upstream
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.secondary)
=======
                .background(group.color.opacity(0.1))
                .foregroundColor(group.color)
>>>>>>> Stashed changes
=======
                .background(group.color.opacity(0.1))
                .foregroundColor(group.color)
>>>>>>> Stashed changes
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
<<<<<<< Updated upstream
<<<<<<< Updated upstream
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// --- КАРТОЧКА ЭКЗАМЕНА B1 ---
struct ExamLevelCardView: View {
    let lessonCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.red.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: "graduationcap.fill").font(.headline).foregroundColor(.red)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Экзамен B1").font(.headline).foregroundColor(.primary)
                Text("Подготовка к сертификации").font(.subheadline).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            Text("\(lessonCount) уроков")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.red.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// --- ЭКРАН СПИСКА УРОКОВ ДЛЯ ВЫБРАННОГО УРОВНЯ ---
=======
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(group.color.opacity(0.3), lineWidth: 1))
        .shadow(color: group.color.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Список Уроков Уровня
>>>>>>> Stashed changes
=======
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(group.color.opacity(0.3), lineWidth: 1))
        .shadow(color: group.color.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Список Уроков Уровня
>>>>>>> Stashed changes
struct GrammarLevelListView: View {
    let title: String
    let lessons: [GrammarLesson]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if lessons.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill").font(.largeTitle).foregroundColor(.gray)
                        Text("Уроки скоро появятся").font(.headline).foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(lessons) { lesson in
                        NavigationLink(destination: GrammarLessonView(lesson: lesson)) {
                            GrammarRowView(lesson: lesson)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

<<<<<<< Updated upstream
<<<<<<< Updated upstream
// --- СТРОКА КОНКРЕТНОГО УРОКА ГРАММАТИКИ ---
=======
// MARK: - Строка Урока Грамматики
>>>>>>> Stashed changes
=======
// MARK: - Строка Урока Грамматики
>>>>>>> Stashed changes
struct GrammarRowView: View {
    let lesson: GrammarLesson
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 44, height: 44)
                Image(systemName: "text.book.closed.fill").foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(.headline).foregroundColor(.primary)
                Text(lesson.description).font(.subheadline).foregroundColor(.gray).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}
