import SwiftUI
import SwiftData

struct ReviewSelectionView: View {
    @Environment(\.modelContext) private var context
    
    // Реактивная выборка всех карточек, которые уже находятся в процессе изучения (reps > 0)
    @Query(filter: #Predicate<VocabItem> { $0.fsrsData.reps > 0 })
    private var studiedWords: [VocabItem]
    
    // Динамический расчет карточек, ожидающих повторения прямо сейчас
    private var dueWords: [VocabItem] {
        let now = Date()
        return studiedWords.filter { $0.fsrsData.due <= now }
    }
    
    // Слабые: карточки на этапе переобучения или с высокой сложностью FSRS
    private var weakWordsCount: Int {
        dueWords.filter { $0.fsrsData.state == .relearning || $0.fsrsData.difficulty > 7.0 }.count
    }
    
    // Средние: стандартные карточки со стабильностью менее 2 недель
    private var mediumWordsCount: Int {
        dueWords.filter { $0.fsrsData.state == .review && $0.fsrsData.difficulty <= 7.0 && $0.fsrsData.stability < 14.0 }.count
    }
    
    // Сильные: стабильно закрепленные в памяти (интервал > 14 дней)
    private var strongWordsCount: Int {
        dueWords.filter { $0.fsrsData.state == .review && $0.fsrsData.stability >= 14.0 }.count
    }
    
    // Индекс здоровья памяти: соотношение карточек с нормальной стабильностью ко всем изученным
    private var memoryHealth: Double {
        guard !studiedWords.isEmpty else { return 1.0 }
        let healthyCount = studiedWords.filter { $0.fsrsData.state == .review && $0.fsrsData.stability > 3.0 }.count
        return Double(healthyCount) / Double(studiedWords.count)
    }
    
    // Грамматика пока остается заглушкой до внедрения FSRS-моделей для грамматических правил
    let weakGrammarCount = 0
    let mediumGrammarCount = 0
    let strongGrammarCount = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    MemoryHealthHeader(health: memoryHealth)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(icon: "text.book.closed.fill", title: "Словарь", color: .blue)
                        
                        VStack(spacing: 12) {
                            // Обязательная передача контекста для инстанцирования ViewModel
                            NavigationLink(destination: FlashcardView(categories: ["Weak"], isReviewMode: true, context: context)) {
                                ReviewCategoryCard(
                                    title: "Слабые слова",
                                    subtitle: "Частые ошибки",
                                    count: weakWordsCount,
                                    icon: "exclamationmark.triangle.fill",
                                    color: .red
                                )
                            }
                            
                            NavigationLink(destination: FlashcardView(categories: ["Medium"], isReviewMode: true, context: context)) {
                                ReviewCategoryCard(
                                    title: "Средние слова",
                                    subtitle: "Нужна практика",
                                    count: mediumWordsCount,
                                    icon: "hourglass",
                                    color: .orange
                                )
                            }
                            
                            NavigationLink(destination: FlashcardView(categories: ["Strong"], isReviewMode: true, context: context)) {
                                ReviewCategoryCard(
                                    title: "Сильные слова",
                                    subtitle: "Надежно в памяти",
                                    count: strongWordsCount,
                                    icon: "checkmark.circle.fill",
                                    color: .green
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(icon: "function", title: "Грамматика", color: .purple)
                        
                        VStack(spacing: 12) {
                            NavigationLink(destination: Text("Grammar Weak")) {
                                ReviewCategoryCard(
                                    title: "Сложные правила",
                                    subtitle: "Требуют внимания",
                                    count: weakGrammarCount,
                                    icon: "xmark.octagon.fill",
                                    color: .red
                                )
                            }
                            
                            NavigationLink(destination: Text("Grammar Medium")) {
                                ReviewCategoryCard(
                                    title: "В процессе",
                                    subtitle: "Иногда путаешь",
                                    count: mediumGrammarCount,
                                    icon: "arrow.triangle.2.circlepath",
                                    color: .orange
                                )
                            }
                            
                            NavigationLink(destination: Text("Grammar Strong")) {
                                ReviewCategoryCard(
                                    title: "Усвоенные темы",
                                    subtitle: "Закрепление",
                                    count: strongGrammarCount,
                                    icon: "star.fill",
                                    color: .green
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            SmartReviewFAB(context: context)
                .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - КОМПОНЕНТ: ХЕДЕР ЗДОРОВЬЯ
struct MemoryHealthHeader: View {
    let health: Double
    
    var healthColor: Color {
        if health > 0.8 { return .green }
        if health > 0.4 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Что повторим?")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Умный алгоритм подобрал слова, которые ты скоро забудешь.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(healthColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundColor(healthColor)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Здоровье памяти")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(health * 100))%")
                            .font(.headline)
                            .bold()
                            .foregroundColor(healthColor)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(healthColor)
                                .frame(width: geo.size.width * health, height: 10)
                        }
                    }
                    .frame(height: 10)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - КОМПОНЕНТ: КАРТОЧКА КАТЕГОРИИ
struct ReviewCategoryCard: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let color: Color
    
    var isCleared: Bool {
        return count == 0 && (color == .red || color == .orange)
    }
    
    var activeColor: Color { isCleared ? .yellow : color }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(activeColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: isCleared ? "trophy.fill" : icon)
                    .font(.title3)
                    .foregroundColor(activeColor)
                    .scaleEffect(isCleared ? 1.1 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(isCleared ? "Отличная работа!" : title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(isCleared ? "Ошибок нет" : subtitle)
                    .font(.subheadline)
                    .foregroundColor(isCleared ? .orange : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isCleared {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.yellow)
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(activeColor)
                        
                        Text(count == 1 ? "объект" : "объектов")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                if !isCleared {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: isCleared ? .yellow.opacity(0.2) : .black.opacity(0.04), radius: isCleared ? 8 : 6, x: 0, y: 3)
    }
}

// MARK: - ЗАГОЛОВОК СЕКЦИИ
struct SectionTitle: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            .frame(width: 52, height: 20, alignment: .center)
            
            Text(title)
                .font(.title3)
                .bold()
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - FAB (КНОПКА УМНЫЙ МИКС)
struct SmartReviewFAB: View {
    let context: ModelContext
    
    var body: some View {
        NavigationLink(destination: FlashcardView(categories: [], isReviewMode: true, context: context)) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text("Умный микс")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
