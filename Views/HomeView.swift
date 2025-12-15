import SwiftUI
import Combine

struct HomeView: View {
    @StateObject var viewModel = StudySessionViewModel()
    @AppStorage("dayStreak") var dayStreak: Int = 1
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. ПРИВЕТСТВИЕ + СТРАЙК
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cześć, Uladzislau! 👋")
                                .font(.title2)
                                .bold()
                            Text("Готов учить польский?")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // ПЛАШКА СТРАЙКА
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("\(dayStreak)")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // 2. ДНЕВНАЯ ЦЕЛЬ
                    DailyGoalCard()
                        .padding(.horizontal)
                    
                    // 3. СТАТИСТИКА
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            // СЛОВА
                            StatItem(
                                value: "\(getLearnedCount())",
                                label: "Слов изучено",
                                icon: "textformat.abc",
                                color: .green
                            )
                            
                            // ГРАММАТИКА
                            let grammarStats = viewModel.getGrammarStats()
                            StatItem(
                                value: "\(grammarStats.learned)/\(grammarStats.total)",
                                label: "Грамматика",
                                icon: "text.book.closed.fill",
                                color: .pink
                            )
                        }
                        
                        // ПОВТОРИТЬ (Кликабельная)
                        // Если ReviewSelectionView существует - оставляем, если нет - можно заменить на FlashcardView(..., isReviewMode: true)
                        NavigationLink(destination: ReviewSelectionView()) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Повторение")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Закрепить изученный материал")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 4. СЕТКА УРОКОВ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Твои уроки")
                                .font(.title3)
                                .bold()
                            Spacer()
                            NavigationLink(destination: LessonsView()) {
                                Text("Все")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            // --- ИСПРАВЛЕНИЕ: Добавлен isReviewMode: false ---
                            NavigationLink(destination: FlashcardView(categories: ["Бюрократия"], isReviewMode: false)) {
                                LessonCard(title: "Бюрократия", subtitle: "Продолжить", icon: "doc.text.fill", color: .orange, progress: 0.4)
                            }
                            
                            NavigationLink(destination: FlashcardView(categories: ["Магазин"], isReviewMode: false)) {
                                LessonCard(title: "Магазин", subtitle: "Новая тема", icon: "cart.fill", color: .green, progress: 0.0)
                            }
                            
                            NavigationLink(destination: QuizView()) {
                                LessonCard(title: "Викторина", subtitle: "Проверь себя", icon: "gamecontroller.fill", color: .purple, progress: 0.8)
                            }
                            
                            // "Случайное" - это тоже режим обучения, просто смешанный
                            NavigationLink(destination: FlashcardView(categories: [], isReviewMode: false)) {
                                LessonCard(title: "Случайное", subtitle: "Всё подряд", icon: "shuffle", color: .blue, progress: 0.2)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                viewModel.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Helpers
    func getLearnedCount() -> Int {
        // Убедись, что ProgressService существует, иначе верни 0
        return ProgressService.shared.getLearnedIDs().count
    }
}

// MARK: - КОМПОНЕНТ: Daily Goal
struct DailyGoalCard: View {
    @State private var todayProgress: Double = 0.65
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: todayProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(todayProgress * 100))%")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Дневная цель")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Продолжай в том же духе!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundColor(.orange)
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(20)
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - КОМПОНЕНТ: Статистика
struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - КОМПОНЕНТ: Карточка Урока
struct LessonCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                if progress > 0 {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(color).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
