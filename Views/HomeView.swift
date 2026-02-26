import SwiftUI
import Combine

// --- МОДЕЛИ ---
enum ChallengeType {
    case words, quiz, grammar
}

struct DailyChallenge: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let target: Int
    var currentProgress: Int
    let reward: Int
    let timeLeft: String
    let type: ChallengeType
    
    var progress: Double { Double(currentProgress) / Double(target) }
}

struct HomeView: View {
    
    @AppStorage("dayStreak") var dayStreak: Int = 1
    @AppStorage("userXP") var userXP: Int = 1250
    
    @AppStorage("homeCategories") private var storage: CategoryStorage = CategoryStorage()
    
    var selectedCategoriesForHome: [String] {
        return storage.items
    }
    
    @State private var showStreakSheet = false
    @State private var showAllCompletedMessage = false
    
    @State private var challenges: [DailyChallenge] = [
        DailyChallenge(title: "Утро лингвиста", description: "Выучи 5 новых слов", target: 5, currentProgress: 3, reward: 50, timeLeft: "2ч 15мин", type: .words),
        DailyChallenge(title: "Грамматика", description: "Пройди 1 урок грамматики", target: 1, currentProgress: 0, reward: 75, timeLeft: "5ч 00мин", type: .grammar),
        DailyChallenge(title: "Идеальная серия", description: "Пройди викторину без ошибок", target: 1, currentProgress: 0, reward: 100, timeLeft: "12ч 45мин", type: .quiz)
    ]
    
    // Сетка для тем: строго заданные ряды для предсказуемой отрисовки
    let gridRows = [
        GridItem(.fixed(160), spacing: 16),
        GridItem(.fixed(160), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerView
                        DailyGoalCard().padding(.horizontal)
                        challengesView
                        reviewLinkView
                        quickPracticeView
                        yourLessonsView
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("").navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $showStreakSheet) { StreakView() }
        }
    }
    
    // --- SUBVIEWS ---
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cześć, Uladzislau!").font(.title2).bold()
                Text("Готов учить польский?").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            
            HStack(spacing: 12) {
                NavigationLink(destination: LeaderboardView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill").foregroundColor(Color(hex: "CD7F32"))
                        Text("Бронза").bold().foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
                }
                
                Button(action: { showStreakSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundColor(.orange)
                        Text("\(dayStreak)").bold().foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
                }
            }
        }
        .padding(.horizontal).padding(.top, 10)
    }
    
    var challengesView: some View {
        Group {
            if !challenges.isEmpty || showAllCompletedMessage {
                VStack(alignment: .leading, spacing: 16) {
                    if !challenges.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "target").foregroundColor(.purple).font(.title3)
                            Text("Ежедневные вызовы").font(.title3).bold()
                        }
                        .padding(.horizontal).transition(.opacity)
                        
                        VStack(spacing: 16) {
                            ForEach(challenges) { challenge in
                                DailyChallengeRow(challenge: challenge) { completeChallenge(challenge) }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy.fill").font(.system(size: 40)).foregroundColor(.yellow).padding(.top, 10).symbolEffect(.bounce, value: showAllCompletedMessage)
                            Text("Все вызовы выполнены!").font(.headline).foregroundColor(.primary)
                            Text("Отличная работа, так держать!").font(.caption).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.5))
                        .cornerRadius(16).padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .transition(.scale(scale: 0.01, anchor: .top).combined(with: .opacity))
            }
        }
    }
    
    var reviewLinkView: some View {
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
            .padding().background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
    
    var quickPracticeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Быстрая тренировка").font(.title3).bold().padding(.horizontal)
            
            HStack(spacing: 16) {
                NavigationLink(destination: QuizView()) {
                    PracticeCard(title: "Викторина", subtitle: "Тест", icon: "gamecontroller.fill", color: .purple)
                }
                NavigationLink(destination: FlashcardView(categories: [], isReviewMode: false)) {
                    PracticeCard(title: "Случайное", subtitle: "Микс", icon: "shuffle", color: .blue)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.instance.impact(style: .medium)
                })
            }
            .padding(.horizontal)
        }
    }
    
    var yourLessonsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Темы").font(.title3).bold().padding(.horizontal)
            
            if selectedCategoriesForHome.isEmpty {
                NavigationLink(destination: LessonsView()) {
                    HStack {
                        Image(systemName: "plus.circle.fill").font(.largeTitle).foregroundColor(.blue)
                        Text("Добавьте темы для изучения").font(.headline).foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity).padding(30)
                    .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: gridRows, spacing: 16) {
                        ForEach(selectedCategoriesForHome, id: \.self) { category in
                            let theme = getTheme(for: category)
                            NavigationLink(destination: FlashcardView(categories: [category], isReviewMode: false)) {
                                LessonCard(
                                    title: category,
                                    subtitle: "Продолжить",
                                    count: "Слова",
                                    icon: theme.icon,
                                    color: theme.color,
                                    progress: 0.0
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12) // Позволяет теням карточек не обрезаться
                }
            }
        }
    }
    
    // --- HELPERS ---
    
    func getTheme(for category: String) -> (icon: String, color: Color) {
        let hash = category.hashValue
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill"]
        
        let color = colors[abs(hash) % colors.count]
        let icon = icons[abs(hash) % icons.count]
        return (icon, color)
    }
    
    func completeChallenge(_ challenge: DailyChallenge) {
        withAnimation(.spring()) { userXP += challenge.reward }
        withAnimation(.easeInOut(duration: 0.5)) {
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }) { challenges.remove(at: index) }
        }
        if challenges.isEmpty {
            withAnimation { showAllCompletedMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeInOut(duration: 0.8)) { showAllCompletedMessage = false }
            }
        }
    }
}

// MARK: - UI COMPONENTS

struct PracticeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Spacer(minLength: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 130)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct LessonCard: View {
    let title: String
    let subtitle: String
    let count: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(color)
            }
            
            Spacer(minLength: 16)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                    
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 4, height: 4)
                    
                    Text(count)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 16)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(color).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .frame(width: 160, height: 160)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct DailyGoalCard: View {
    @AppStorage("userXP") var userXP: Int = 1250
    @AppStorage("dailyWordGoal") var dailyGoal: Int = 10
    
    @State private var wordsLearnedToday: Int = 8
    @State private var goalCompleted = false
    
    @State private var showSuccessBounce = false
    @State private var showGlowPulse = false
    @State private var showXParticles = false
    
    var progress: Double { min(Double(wordsLearnedToday) / Double(dailyGoal), 1.0) }
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption).bold().foregroundColor(.white)
                    .contentTransition(.numericText(value: progress * 100))
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goalCompleted ? "Цель выполнена!" : "Дневная цель")
                    .font(.headline).foregroundColor(.white)
                    .transition(.push(from: .bottom))
                    .id("title" + (goalCompleted ? "done" : "work"))
                
                if goalCompleted {
                    Text("+50 XP получено").font(.caption).bold().foregroundColor(.yellow)
                        .transition(.push(from: .top)).id("xpSubtitle")
                } else {
                    Text("Выучено: \(wordsLearnedToday) / \(dailyGoal) слов")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                        .transition(.opacity).id("progressSubtitle")
                }
            }
            Spacer()
            ZStack {
                if showGlowPulse {
                    Circle()
                        .fill(RadialGradient(colors: [.yellow.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 40))
                        .scaleEffect(1.5).opacity(0)
                        .transition(.opacity)
                }
                if showXParticles {
                    ForEach(0..<8) { i in
                        Circle()
                            .fill(Color.yellow).frame(width: 5, height: 5)
                            .offset(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -40...0))
                            .opacity(0)
                            .animation(.easeOut(duration: 0.8).delay(Double(i) * 0.05), value: showXParticles)
                    }
                }
                Image(systemName: goalCompleted ? "trophy.fill" : "target")
                    .font(.system(size: 34))
                    .foregroundColor(goalCompleted ? .yellow : .white.opacity(0.8))
                    .scaleEffect(showSuccessBounce ? 1.3 : 1.0)
                    .rotationEffect(.degrees(showSuccessBounce && goalCompleted ? 360 : 0))
                    .transition(.scale.combined(with: .opacity))
                    .id(goalCompleted ? "trophy" : "target")
            }
            .frame(width: 50, height: 50)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: goalCompleted ? [Color(hex: "00b09b"), Color(hex: "96c93d")] : [Color.blue, Color(hex: "3a7bd5")]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: goalCompleted ? .green.opacity(0.3) : .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.5), value: goalCompleted)
        .onTapGesture { incrementProgressTest() }
    }
    
    func incrementProgressTest() {
        guard wordsLearnedToday < dailyGoal else { return }
        wordsLearnedToday += 1
        if wordsLearnedToday == dailyGoal && !goalCompleted {
            playSuccessAnimation()
        }
    }
    
    func playSuccessAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { goalCompleted = true; showSuccessBounce = true }
        withAnimation(.easeOut(duration: 0.8)) { showGlowPulse = true }
        withAnimation(.easeOut.delay(0.1)) { showXParticles = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { showSuccessBounce = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { userXP += 50 }
        }
    }
}

struct DailyChallengeRow: View {
    let challenge: DailyChallenge
    let onComplete: () -> Void
    @State private var isCompleted = false
    @State private var particles: [ExplosionParticle] = []
    
    var body: some View {
        ZStack {
            if isCompleted {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: .orange.opacity(0.6), radius: 10, x: 0, y: 5)
                    ForEach(particles) { p in Circle().fill(p.color).frame(width: p.size, height: p.size).offset(x: p.x, y: p.y).opacity(p.opacity) }
                    HStack(spacing: 8) { Image(systemName: "star.fill").font(.title).foregroundColor(.white); Text("+\(challenge.reward)").font(.largeTitle).bold().foregroundColor(.white) }.scaleEffect(1.1)
                }.transition(.opacity)
            } else {
                DailyChallengeCardContent(challenge: challenge).contentShape(Rectangle()).onTapGesture { animateSuccess() }.transition(.opacity)
            }
        }.frame(height: 100)
    }
    
    func animateSuccess() {
        for _ in 0..<30 { particles.append(ExplosionParticle()) }
        withAnimation(.easeInOut(duration: 0.3)) { isCompleted = true }
        withAnimation(.easeOut(duration: 1.0)) { for i in 0..<particles.count { particles[i].x = CGFloat.random(in: -150...150); particles[i].y = CGFloat.random(in: -100...100); particles[i].opacity = 0 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onComplete() }
    }
}

struct ExplosionParticle: Identifiable { let id = UUID(); var x: CGFloat = 0; var y: CGFloat = 0; let size = CGFloat.random(in: 4...8); let color = [Color.white, Color.yellow, Color.orange].randomElement()!; var opacity: Double = 1.0 }

struct DailyChallengeCardContent: View {
    let challenge: DailyChallenge
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) { Text(challenge.title).font(.headline).foregroundColor(.primary); Text(challenge.description).font(.caption).foregroundColor(.gray).lineLimit(2) }
                Spacer()
                HStack(spacing: 4) { Image(systemName: "medal.fill"); Text("+\(challenge.reward)").bold() }.font(.caption).padding(.horizontal, 10).padding(.vertical, 6).background(Color.yellow.opacity(0.2)).foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.0)).cornerRadius(12)
            }
            VStack(spacing: 6) {
                HStack { Text("\(challenge.currentProgress) / \(challenge.target)").font(.caption2).bold().foregroundColor(.gray); Spacer(); HStack(spacing: 4) { Image(systemName: "clock"); Text(challenge.timeLeft) }.font(.caption2).foregroundColor(.gray) }
                GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.gray.opacity(0.15)).frame(height: 8); Capsule().fill(LinearGradient(colors: [Color.purple, Color.pink], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * CGFloat(challenge.progress), height: 8) } }.frame(height: 8)
            }
        }.padding(16).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
