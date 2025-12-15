import SwiftUI

struct LessonsView: View {
    // --- STATE ---
    @State private var selectedTab = 0 // 0 = Слова, 1 = Грамматика
    @State private var searchText = ""
    
    // Данные
    @State private var categories: [String] = []
    @State private var grammarLessons: [GrammarLesson] = []
    
    // Настройка сетки
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var filteredCategories: [String] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // --- BODY ---
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Фон
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Хедер и Поиск
                    VStack(spacing: 16) {
                        pickerView
                        searchBar
                    }
                    .padding(.bottom, 10)
                    .background(Color(UIColor.systemGroupedBackground))
                    
                    // 2. Основной контент (Скролл)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // (Баннер убран)
                            
                            if selectedTab == 0 {
                                // СЕТКА СЛОВ
                                if categories.isEmpty {
                                    loadingView
                                } else {
                                    wordsGridView
                                }
                            } else {
                                // СПИСОК ГРАММАТИКИ
                                if grammarLessons.isEmpty {
                                    loadingView
                                } else {
                                    grammarListView
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Отступ под таббар
                    }
                }
            }
            .navigationTitle("Библиотека")
            .onAppear {
                loadData()
            }
        }
    }
    
    // --- КОМПОНЕНТЫ UI ---
    
    // 1. Переключатель
    var pickerView: some View {
        Picker("Тип", selection: $selectedTab) {
            Text("Слова").tag(0)
            Text("Грамматика").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // 2. Поиск
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Поиск тем...", text: $searchText)
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // 3. Сетка Слов
    var wordsGridView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Категории")
                .font(.title2)
                .bold()
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredCategories, id: \.self) { category in
                    NavigationLink(destination: FlashcardView(categories: [category], isReviewMode: false)) {
                        CategoryCardView(category: category)
                    }
                }
            }
        }
    }
    
    // 4. Список Грамматики
    var grammarListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Правила")
                .font(.title2)
                .bold()
            
            ForEach(grammarLessons) { lesson in
                NavigationLink(destination: GrammarDetailView(lesson: lesson)) {
                    GrammarRowView(lesson: lesson)
                }
            }
        }
    }
    
    // 5. Загрузка
    var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Загрузка контента...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // --- ЛОГИКА ---
    func loadData() {
        // Загрузка слов
        let words = DataLoader.shared.loadWords()
        let unique = Set(words.map { $0.category })
        self.categories = Array(unique).sorted()
        
        // Загрузка грамматики
        self.grammarLessons = DataLoader.shared.loadGrammar()
    }
}

// --- SUBVIEWS (Внешний вид карточек) ---

struct CategoryCardView: View {
    let category: String
    
    // Генерация цвета и иконки на основе названия
    var theme: (icon: String, color: Color) {
        let hash = category.hashValue
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill"]
        
        let color = colors[abs(hash) % colors.count]
        let icon = icons[abs(hash) % icons.count]
        return (icon, color)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: theme.icon)
                    .font(.title2)
                    .foregroundColor(theme.color)
                    .padding(10)
                    .background(theme.color.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
            }
            
            Text(category)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text("Учить")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(theme.color)
            }
        }
        .padding()
        .frame(height: 140)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct GrammarRowView: View {
    let lesson: GrammarLesson
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Уровень (A1, A2) в кружочке
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(lesson.level)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(lesson.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Детальный просмотр грамматики
struct GrammarDetailView: View {
    let lesson: GrammarLesson
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок урока
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.title)
                        .font(.largeTitle)
                        .bold()
                    Text(lesson.description)
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 10)
                
                Divider()
                
                // --- ВЫВОД ШАГОВ (Steps) ---
                ForEach(lesson.steps) { step in
                    VStack(alignment: .leading, spacing: 12) {
                        
                        if step.type == .theory {
                            // ТЕОРИЯ
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.blue)
                                Text(step.title)
                                    .font(.title3)
                                    .bold()
                            }
                            
                            Text(step.content)
                                .font(.body)
                                .lineSpacing(6)
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(12)
                            
                        } else if step.type == .quiz {
                            // КВИЗ
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Проверка знаний")
                                    .font(.headline)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(step.question ?? "Вопрос")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                if let answers = step.answers {
                                    ForEach(answers, id: \.self) { answer in
                                        HStack {
                                            Circle().stroke(Color.gray, lineWidth: 2).frame(width: 12)
                                            Text(answer)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
