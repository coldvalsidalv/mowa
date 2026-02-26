import SwiftUI

struct LessonsView: View {
    @StateObject private var viewModel = LessonsViewModel()
    @State private var selectedTab = 0
    
    let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Тип", selection: $selectedTab) {
                        Text("Слова").tag(0)
                        Text("Грамматика").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGroupedBackground))
                    .onChange(of: selectedTab) { _, newTab in
                        if newTab == 1 { viewModel.isEditMode = false }
                        viewModel.loadCompletedGrammar()
                    }
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
                                wordsSection
                            } else {
                                grammarSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Библиотека")
            .searchable(text: $viewModel.searchText, prompt: selectedTab == 0 ? "Поиск тем..." : "Поиск правил...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == 0 && !viewModel.categories.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.isEditMode.toggle() }
                        }) {
                            Image(systemName: viewModel.isEditMode ? "checkmark" : "pencil")
                                .font(.body.bold())
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .onAppear { viewModel.loadData() }
            .navigationDestination(for: String.self) { route in
                // Маршрутизация на основе значений (Value-based navigation)
                if route.hasPrefix("lesson_") {
                    let id = String(route.dropFirst(7))
                    if let lesson = viewModel.grammarLessons.first(where: { $0.id == id }) {
                        GrammarLessonView(lesson: lesson)
                    }
                } else if route.hasPrefix("group_") {
                    let id = String(route.dropFirst(6))
                    if let group = viewModel.grammarGroups.first(where: { $0.id == id }) {
                        GrammarLevelListView(group: group, lessons: viewModel.lessons(for: group.id))
                    }
                } else if route.hasPrefix("category_") {
                    let name = String(route.dropFirst(9))
                    FlashcardView(categories: [name], isReviewMode: false)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var wordsSection: some View {
        if viewModel.categories.isEmpty {
            ProgressView().scaleEffect(1.5).padding(.top, 50)
        } else if viewModel.filteredCategories.isEmpty {
            Text("Ничего не найдено").foregroundColor(.gray).padding(.top, 50)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(viewModel.filteredCategories) { stat in
                    if viewModel.isEditMode {
                        CategoryCardView(stat: stat, isSelected: viewModel.selectedCategories.contains(stat.id), isEditMode: true)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleCategorySelection(stat.id) }
                            }
                    } else {
                        NavigationLink(value: "category_\(stat.id)") {
                            CategoryCardView(stat: stat, isSelected: false, isEditMode: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var grammarSection: some View {
        if viewModel.grammarLessons.isEmpty {
            ProgressView().scaleEffect(1.5).padding(.top, 50)
        } else if !viewModel.searchText.isEmpty {
            let searchResults = viewModel.searchResultsGrammar
            if searchResults.isEmpty {
                Text("Ничего не найдено").foregroundColor(.gray).padding(.top, 50)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(searchResults) { lesson in
                        let isCompleted = viewModel.completedGrammarLessons.contains(lesson.id)
                        NavigationLink(value: "lesson_\(lesson.id)") {
                            GrammarRowView(lesson: lesson, isCompleted: isCompleted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.grammarGroups) { group in
                    NavigationLink(value: "group_\(group.id)") {
                        LevelCardView(group: group, lessonCount: viewModel.lessons(for: group.id).count)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Components

struct CategoryCardView: View {
    let stat: CategoryStat
    let isSelected: Bool
    let isEditMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(stat.color.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: stat.icon).font(.title3).foregroundColor(stat.color)
                }
                Spacer()
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundColor(isSelected ? .blue : Color(UIColor.tertiaryLabel))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(stat.name).font(.system(.headline, design: .rounded)).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.8)
                HStack {
                    Text("\(stat.learnedWords)/\(stat.totalWords) слов").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(stat.progress * 100))%").font(.caption).bold().foregroundColor(stat.color)
                }
                
                // Кастомный прогресс-бар без искажений scaleEffect
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(stat.color)
                            .frame(width: max(0, geo.size.width * CGFloat(stat.progress)))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(isSelected && isEditMode ? Color.blue.opacity(0.05) : Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected && isEditMode ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

struct GrammarRowView: View {
    let lesson: GrammarLesson
    let isCompleted: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(isCompleted ? Color.green.opacity(0.15) : Color.blue.opacity(0.1)).frame(width: 44, height: 44)
                Image(systemName: isCompleted ? "checkmark" : "book.closed.fill").foregroundColor(isCompleted ? .green : .blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(.headline).foregroundColor(.primary)
                Text(lesson.description).font(.subheadline).foregroundColor(.gray).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.4))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }
}

// Унифицированная карточка уровня
struct LevelCardView: View {
    let group: GrammarGroupUI
    let lessonCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(group.color.opacity(0.15)).frame(width: 52, height: 52)
                if let text = group.iconText {
                    Text(text).font(.headline).bold().foregroundColor(group.color)
                } else if let symbol = group.iconSymbol {
                    Image(systemName: symbol).font(.headline).foregroundColor(group.color)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title).font(.headline).foregroundColor(.primary)
                Text(group.subtitle).font(.subheadline).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            Text("\(lessonCount) уроков")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(group.isExam ? group.color.opacity(0.1) : Color(UIColor.systemGray5))
                .foregroundColor(group.isExam ? group.color : .secondary)
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(group.isExam ? group.color.opacity(0.3) : Color.clear, lineWidth: 1))
        .shadow(color: group.isExam ? group.color.opacity(0.05) : Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// Отвязанный список уроков
struct GrammarLevelListView: View {
    let group: GrammarGroupUI
    let lessons: [GrammarLesson]
    @State private var completedIDs: Set<String> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(lessons) { lesson in
                    let isCompleted = completedIDs.contains(lesson.id)
                    NavigationLink(value: "lesson_\(lesson.id)") {
                        GrammarRowView(lesson: lesson, isCompleted: isCompleted)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear { loadCompleted() }
    }
    
    private func loadCompleted() {
        if let data = UserDefaults.standard.array(forKey: "completedGrammarLessons") as? [String] {
            completedIDs = Set(data)
        }
    }
}
