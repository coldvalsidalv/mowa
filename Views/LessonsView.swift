import SwiftUI
import SwiftData

struct LessonsView: View {
    @Environment(\.modelContext) private var modelContext
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
                    VStack(spacing: 16) {
                        pickerView
                        searchBar
                    }
                    .padding(.bottom, 10)
                    .background(Color(UIColor.systemGroupedBackground))
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
                                if viewModel.categories.isEmpty {
                                    loadingView
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
                                viewModel.isEditMode.toggle()
                            }
                        }) {
                            Image(systemName: viewModel.isEditMode ? "checkmark" : "pencil")
                                .font(.body.bold())
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .onAppear { viewModel.loadData(context: modelContext) }
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
                    NavigationLink(destination: FlashcardView(categories: [stat.id], isReviewMode: false, context: modelContext)) {
                        CategoryCardView(stat: stat, isSelected: false, isEditMode: false)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var grammarLevelsView: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.grammarGroups) { group in
                let groupLessons = viewModel.lessons(for: group.id)
                
                NavigationLink(destination: GrammarLevelListView(title: group.title, lessons: groupLessons, completedIDs: viewModel.completedGrammarLessonIDs)) {
                    if group.isExam {
                        ExamLevelCardView(group: group)
                    } else {
                        GrammarLevelCardView(group: group)
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

// MARK: - Карточка Категории Слов
struct CategoryCardView: View {
    let stat: CategoryStat
    let isSelected: Bool
    let isEditMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(stat.color.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: stat.icon).font(.title3).foregroundColor(stat.color)
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

// MARK: - Карточка Уровня Грамматики
struct GrammarLevelCardView: View {
    let group: GrammarGroupUI
    
    var body: some View {
        VStack(spacing: 0) {
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
                    Text(group.subtitle).font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                Text("\(group.completedLessons)/\(group.totalLessons)")
                    .font(.caption).bold()
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(group.progress >= 1.0 ? group.color.opacity(0.1) : Color(UIColor.systemGray5))
                    .foregroundColor(group.progress >= 1.0 ? group.color : .secondary)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ProgressView(value: group.progress)
                .tint(group.color)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Карточка Экзамена B1
struct ExamLevelCardView: View {
    let group: GrammarGroupUI
    
    var body: some View {
        VStack(spacing: 0) {
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
                }
                Spacer()
                Text("\(group.completedLessons)/\(group.totalLessons)")
                    .font(.caption).bold()
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(group.color.opacity(0.1))
                    .foregroundColor(group.color)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ProgressView(value: group.progress)
                .tint(group.color)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(group.color.opacity(0.3), lineWidth: 1))
        .shadow(color: group.color.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Список Уроков Уровня
struct GrammarLevelListView: View {
    let title: String
    let lessons: [GrammarLesson]
    let completedIDs: Set<String>
    
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
                        let isCompleted = completedIDs.contains(lesson.id)
                        NavigationLink(destination: GrammarLessonView(lesson: lesson)) {
                            GrammarRowView(lesson: lesson, isCompleted: isCompleted)
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

// MARK: - Строка Урока Грамматики
struct GrammarRowView: View {
    let lesson: GrammarLesson
    let isCompleted: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)).frame(width: 44, height: 44)
                Image(systemName: isCompleted ? "checkmark" : "text.book.closed.fill")
                    .foregroundColor(isCompleted ? .green : .blue)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCompleted ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}
