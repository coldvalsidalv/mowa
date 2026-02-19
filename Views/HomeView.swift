import SwiftUI
import Combine

// --- МОДЕЛЬ ДЛЯ ВЫЗОВА ---
struct DailyChallenge: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let currentProgress: Int
    let target: Int
    let reward: Int
    let timeLeft: String
    
    var progress: Double {
        return Double(currentProgress) / Double(target)
    }
}

struct HomeView: View {
    @StateObject var viewModel = StudySessionViewModel()
    @AppStorage("dayStreak") var dayStreak: Int = 1
    @State private var showStreakSheet = false
    
    // --- НАСТРОЙКА ГОРИЗОНТАЛЬНОЙ СЕТКИ ---
    // Два фиксированных ряда высотой 185pt (под размер карточки + тень)
    let rows = [
        GridItem(.fixed(185), spacing: 16),
        GridItem(.fixed(185), spacing: 16)
    ]
    
    // Данные вызовов
    let challenges = [
        DailyChallenge(title: "Утро лингвиста", description: "Выучи 5 новых слов до полудня", currentProgress: 3, target: 5, reward: 50, timeLeft: "2ч 15мин"),
        DailyChallenge(title: "Идеальная серия", description: "Пройди викторину без ошибок", currentProgress: 0, target: 1, reward: 100, timeLeft: "12ч 45мин")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // 1. ХЕДЕР (ПРИВЕТСТВИЕ + СТРИК)
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
                        Button(action: { showStreakSheet = true }) {
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
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // 2. ДНЕВНАЯ ЦЕЛЬ
                    DailyGoalCard()
                        .padding(.horizontal)
                    
                    // 3. ЕЖЕДНЕВНЫЕ ВЫЗОВЫ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Ежедневные вызовы")
                                .font(.title3)
                                .bold()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(challenges) { challenge in
                                DailyChallengeCard(challenge: challenge)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 4. ПОВТОРЕНИЕ (КНОПКА)
                    NavigationLink(destination: ReviewSelectionView()) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.1)).frame(width: 50, height: 50)
                                Image(systemName: "arrow.clockwise").font(.title2).foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Повторение").font(.headline).foregroundColor(.primary)
                                Text("Закрепить материал").font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.4))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    
                    // 5. ТВОИ УРОКИ (ГОРИЗОНТАЛЬНАЯ СЕТКА 2x4)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Твои уроки")
                                .font(.title3)
                                .bold()
                            Spacer()
                            NavigationLink(destination: LessonsView()) {
                                Text("Все").font(.subheadline).foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // ScrollView Horizontal + LazyHGrid = Карусель с сеткой
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: rows, spacing: 16) {
                                
                                // --- ПЕРВЫЙ СТОЛБЕЦ ---
                                NavigationLink(destination: FlashcardView(categories: ["Бюрократия"], isReviewMode: false)) {
                                    LessonCard(title: "Бюрократия", subtitle: "Продолжить", count: "25 слов", icon: "doc.text.fill", color: .orange, progress: 0.4)
                                }
                                NavigationLink(destination: FlashcardView(categories: ["Магазин"], isReviewMode: false)) {
                                    LessonCard(title: "Магазин", subtitle: "Новая тема", count: "18 слов", icon: "cart.fill", color: .green, progress: 0.0)
                                }
                                
                                // --- ВТОРОЙ СТОЛБЕЦ ---
                                NavigationLink(destination: FlashcardView(categories: ["Путешествия"], isReviewMode: false)) {
                                    LessonCard(title: "Путешествия", subtitle: "Пора в путь", count: "30 слов", icon: "airplane", color: .cyan, progress: 0.1)
                                }
                                NavigationLink(destination: FlashcardView(categories: ["Семья"], isReviewMode: false)) {
                                    LessonCard(title: "Семья", subtitle: "Родные", count: "15 слов", icon: "figure.2.and.child.holdinghands", color: .pink, progress: 0.0)
                                }
                                
                                // --- ТРЕТИЙ СТОЛБЕЦ ---
                                NavigationLink(destination: FlashcardView(categories: ["Еда"], isReviewMode: false)) {
                                    LessonCard(title: "Еда", subtitle: "Ресторан", count: "40 слов", icon: "fork.knife", color: .red, progress: 0.0)
                                }
                                NavigationLink(destination: FlashcardView(categories: ["Спорт"], isReviewMode: false)) {
                                    LessonCard(title: "Спорт", subtitle: "Активность", count: "20 слов", icon: "figure.run", color: .indigo, progress: 0.0)
                                }
                                
                                // --- ЧЕТВЕРТЫЙ СТОЛБЕЦ (Служебные) ---
                                NavigationLink(destination: QuizView()) {
                                    LessonCard(title: "Викторина", subtitle: "Проверь себя", count: "∞ вопросов", icon: "gamecontroller.fill", color: .purple, progress: 0.8)
                                }
                                NavigationLink(destination: FlashcardView(categories: [], isReviewMode: false)) {
                                    LessonCard(title: "Случайное", subtitle: "Микс", count: "Все слова", icon: "shuffle", color: .blue, progress: 0.2)
                                }
                            }
                            .padding(.horizontal)
                            // Добавляем отступ снизу для тени нижней карточки
                            .padding(.bottom, 20)
                        }
                        // Фиксируем высоту скролла, чтобы вместились 2 ряда + отступы
                        // 185 (ряд 1) + 16 (spacing) + 185 (ряд 2) + 20 (padding bottom) = ~406
                        .frame(height: 410)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear { viewModel.objectWillChange.send() }
            .sheet(isPresented: $showStreakSheet) { StreakView() }
        }
    }
}

// MARK: - LessonCard
struct LessonCard: View {
    let title: String
    let subtitle: String
    let count: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Верх: Иконка + Бейдж
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                Text(count)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.systemBackground).opacity(0.6))
                    .foregroundColor(.gray)
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Тексты
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Низ: Прогресс + Play
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(color).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)
                
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(color)
            }
        }
        .padding(16)
        .frame(width: 170, height: 185) // Фиксированный размер для сетки
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - DailyChallengeCard
struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title).font(.headline).foregroundColor(.primary)
                    Text(challenge.description).font(.caption).foregroundColor(.gray).lineLimit(2)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "medal.fill")
                    Text("+\(challenge.reward)").bold()
                }
                .font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.yellow.opacity(0.2)).foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.0)).cornerRadius(12)
            }
            VStack(spacing: 6) {
                HStack {
                    Text("\(challenge.currentProgress) / \(challenge.target)").font(.caption2).bold().foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(challenge.timeLeft)
                    }
                    .font(.caption2).foregroundColor(.gray)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15)).frame(height: 8)
                        Capsule().fill(LinearGradient(colors: [Color.purple, Color.pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(challenge.progress), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - DailyGoalCard
struct DailyGoalCard: View {
    @State private var todayProgress: Double = 0.65
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 8)
                Circle().trim(from: 0, to: todayProgress).stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int(todayProgress * 100))%").font(.caption).bold().foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text("Дневная цель").font(.headline).foregroundColor(.white)
                Text("Продолжай в том же духе!").font(.caption).foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Image(systemName: "flame.fill").font(.title).foregroundColor(.orange)
        }
        .padding().background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), startPoint: .leading, endPoint: .trailing)).cornerRadius(20).shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}
