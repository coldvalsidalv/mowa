import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var examPlan = ExamPlanStore()
    @State private var categoryStats: [String: (total: Int, learned: Int)] = [:]

    @State private var showExamSetup = false
    @State private var startExamLevel: ExamLevel? = nil

    @AppStorage(StorageKeys.dayStreak) private var dayStreak: Int = 0
    @AppStorage(StorageKeys.userName) private var userName: String = ""
    @AppStorage(StorageKeys.homeCategories) private var storage: CategoryStorage = CategoryStorage()

    @State private var showStreakSheet = false
    @State private var recommendedCategory: String? = nil

    @Binding var selectedTab: Int
    @Binding var triggerLessonsEditMode: Bool
    
    let gridRows = [
        GridItem(.fixed(160), spacing: 16),
        GridItem(.fixed(160), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView

                    ExamCard(
                        store: examPlan,
                        onSetup: { showExamSetup = true },
                        onStart: { startExamLevel = $0 }
                    )

                    DailyGoalCard(
                        progress: viewModel.dailyGoalProgress,
                        isCompleted: viewModel.isDailyGoalCompleted,
                        wordsLearned: viewModel.wordsLearnedToday,
                        goal: viewModel.dailyWordGoal,
                        onTap: {}
                    )
                    .padding(.horizontal)
                    
                    challengesView
                    reviewLinkView
                    writingLinkView
                    quickPracticeView
                    yourLessonsView
                }
                .padding(.bottom, 30)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showStreakSheet) {
                StreakView(onStartLesson: {
                    if let best = getBestCategory() {
                        recommendedCategory = best
                    }
                })
            }
            .navigationDestination(item: $recommendedCategory) { category in
                FlashcardView(categories: [category], isReviewMode: false, context: modelContext)
            }
            .navigationDestination(item: $startExamLevel) { level in
                FlashcardView(level: level.rawValue, context: modelContext)
            }
            .sheet(isPresented: $showExamSetup) {
                ExamSetupSheet(store: examPlan)
            }
            .onAppear {
                VocabSyncService.shared.syncIfNeeded(context: modelContext)
                viewModel.refreshStats(context: modelContext)
                loadCategoryStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: .vocabularyDidChange)) { _ in
                loadCategoryStats()
            }
        }
    }
    
    // MARK: - Секции
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(userName.isEmpty ? "Cześć!" : "Cześć, \(userName)!").font(.title2).bold()
                Text("Готов учить польский?").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            
            HStack(spacing: 12) {
                NavigationLink(destination: LeaderboardView()) {
                    Image(systemName: viewModel.currentLeague.icon)
                        .font(.body.bold())
                        .foregroundColor(viewModel.currentLeague.gradientColors.first ?? .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
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
    
    private var challengesView: some View {
        Group {
            if !viewModel.challenges.isEmpty || viewModel.showAllCompletedMessage {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.challenges.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "target").foregroundColor(.purple).font(.title3)
                            Text("Ежедневные вызовы").font(.title3).bold()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            ForEach(viewModel.challenges) { challenge in
                                DailyChallengeRow(challenge: challenge) {
                                    viewModel.completeChallenge(challenge)
                                } destination: {
                                    challengeDestination(for: challenge)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                                .padding(.top, 10)
                                .symbolEffect(.bounce, value: viewModel.showAllCompletedMessage)
                            
                            Text("Все вызовы выполнены!").font(.headline).foregroundColor(.primary)
                            Text("Отличная работа, так держать!").font(.caption).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.5))
                        .cornerRadius(16).padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    private var reviewLinkView: some View {
        // Если ReviewSelectionView переписан под SwiftData, ему тоже нужен context
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
    
    private var writingLinkView: some View {
        NavigationLink(destination: WritingTaskListView()) {
            HStack {
                ZStack {
                    Circle().fill(Color.indigo.opacity(0.1)).frame(width: 50, height: 50)
                    Image(systemName: "square.and.pencil").font(.title2).foregroundColor(.indigo)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Письмо B1").font(.headline).foregroundColor(.primary)
                    Text("Проверка эссе по критериям экзамена").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.4))
            }
            .padding().background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
    }

    private var quickPracticeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Быстрая тренировка").font(.title3).bold().padding(.horizontal)
            
            HStack(spacing: 16) {
                NavigationLink(destination: QuizView()) {
                    PracticeCard(title: "Викторина", subtitle: "Тест", icon: "gamecontroller.fill", color: .purple)
                }
                NavigationLink(destination: FlashcardView(categories: [], isReviewMode: false, context: modelContext)) {
                    PracticeCard(title: "Случайное", subtitle: "Микс", icon: "shuffle", color: .blue)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var yourLessonsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Темы").font(.title3).bold().padding(.horizontal)
            
            if storage.items.isEmpty {
                Button {
                    triggerLessonsEditMode = true
                    selectedTab = 1
                } label: {
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
                        ForEach(storage.items, id: \.self) { category in
                            let theme = getTheme(for: category)
                            let stats = categoryStats[category]
                            let total = stats?.total ?? 0
                            let learned = stats?.learned ?? 0
                            let progress = total > 0 ? Double(learned) / Double(total) : 0.0
                            let countText = total > 0 ? "\(learned)/\(total)" : "Слова"
                            let isCompleted = total > 0 && progress >= 1.0
                            
                            NavigationLink(destination: FlashcardView(categories: [category], isReviewMode: false, context: modelContext)) {
                                LessonCard(
                                    title: category,
                                    subtitle: isCompleted ? "Завершено" : "Продолжить",
                                    count: countText,
                                    icon: theme.icon,
                                    color: isCompleted ? .green : theme.color,
                                    progress: progress
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Утилиты UI и Логика
    
    private func getTheme(for category: String) -> (icon: String, color: Color) {
        let hash = category.stableHash
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal]
        let icons = ["text.book.closed.fill", "graduationcap.fill", "lightbulb.fill", "globe.europe.africa.fill", "bubble.left.and.bubble.right.fill"]
        return (icons[hash % icons.count], colors[hash % colors.count])
    }
    
    @ViewBuilder
    private func challengeDestination(for challenge: DailyChallenge) -> some View {
        switch challenge.type {
        case .words:
            FlashcardView(categories: [], isReviewMode: false, context: modelContext)
        case .quiz:
            QuizView()
        case .grammar:
            LessonsView(initialTab: 1)
        }
    }

    private func loadCategoryStats() {
        var stats: [String: (total: Int, learned: Int)] = [:]
        for category in storage.items {
            let cat = category
            let totalDesc = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.category == cat })
            let learnedDesc = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.category == cat && $0.fsrsData.reps > 0 })
            let total = (try? modelContext.fetchCount(totalDesc)) ?? 0
            let learned = (try? modelContext.fetchCount(learnedDesc)) ?? 0
            stats[cat] = (total: total, learned: learned)
        }
        categoryStats = stats
    }

    private func getBestCategory() -> String? {
        var bestCategory: String? = nil
        var highestProgress: Double = -1.0

        for category in storage.items {
            let stats = categoryStats[category]
            let total = stats?.total ?? 0
            guard total > 0 else { continue }
            let learned = stats?.learned ?? 0
            let progress = Double(learned) / Double(total)

            if progress < 1.0 && progress > highestProgress {
                highestProgress = progress
                bestCategory = category
            }
        }

        return bestCategory ?? storage.items.first
    }
}

// MARK: - Компоненты UI

struct DailyGoalCard: View {
    let progress: Double
    let isCompleted: Bool
    let wordsLearned: Int
    let goal: Int
    let onTap: () -> Void
    
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
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isCompleted ? "Цель выполнена!" : "Дневная цель")
                    .font(.headline).foregroundColor(.white)
                
                if isCompleted {
                    Text("+50 XP получено").font(.caption).bold().foregroundColor(.yellow)
                } else {
                    Text("Выучено: \(wordsLearned) / \(goal) слов")
                        .font(.caption).foregroundColor(.white.opacity(0.8))
                }
            }
            Spacer()
            
            Image(systemName: isCompleted ? "trophy.fill" : "target")
                .font(.system(size: 34))
                .foregroundColor(isCompleted ? .yellow : .white.opacity(0.8))
                .symbolEffect(.bounce, value: isCompleted)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: isCompleted ? [Color(red: 0, green: 176/255, blue: 155/255), Color(red: 150/255, green: 201/255, blue: 61/255)] : [Color.blue, Color(red: 58/255, green: 123/255, blue: 213/255)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: isCompleted ? .green.opacity(0.3) : .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        .onTapGesture { onTap() }
    }
}


// MARK: - DailyChallengeRow: навигация к заданию + анимация при выполнении

struct DailyChallengeRow<Destination: View>: View {
    let challenge: DailyChallenge
    let onComplete: () -> Void
    let destination: () -> Destination

    @State private var isAnimatingCompletion = false

    var body: some View {
        ZStack {
            if isAnimatingCompletion {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .orange.opacity(0.6), radius: 10, x: 0, y: 5)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill").font(.title).foregroundColor(.white)
                            Text("+\(challenge.reward)").font(.largeTitle).bold().foregroundColor(.white)
                        }
                    )
                    .transition(.opacity)
            } else {
                NavigationLink(destination: destination()) {
                    DailyChallengeCardContent(challenge: challenge)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .frame(height: 100)
        // Анимация запускается когда задание выполнено (прогресс достиг цели)
        .onChange(of: challenge.isCompleted) { _, completed in
            guard completed, !isAnimatingCompletion else { return }
            withAnimation(.easeInOut(duration: 0.3)) { isAnimatingCompletion = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run {
                    withAnimation { onComplete() }
                }
            }
        }
    }
}

struct DailyChallengeCardContent: View {
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
                .font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.yellow.opacity(0.2))
                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.0))
                .cornerRadius(12)
            }
            VStack(spacing: 6) {
                HStack {
                    Text("\(challenge.currentProgress) / \(challenge.target)").font(.caption2).bold().foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 4) { Image(systemName: "clock"); Text(challenge.timeLeft) }.font(.caption2).foregroundColor(.gray)
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
        .padding(16).background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

struct PracticeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.title2).foregroundColor(color).frame(width: 44, height: 44)
                .background(color.opacity(0.1)).clipShape(Circle())
            
            Spacer(minLength: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded)).fontWeight(.bold).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.75)
                Text(subtitle).font(.system(.subheadline, design: .rounded)).foregroundColor(.gray).lineLimit(1)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 130)
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
                    Circle().fill(color.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.title3).fontWeight(.semibold).foregroundColor(color)
                }
                Spacer()
                Image(systemName: "play.circle.fill").font(.system(size: 26)).foregroundColor(color)
            }
            
            Spacer(minLength: 16)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(.title3, design: .rounded)).fontWeight(.bold).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.8)
                
                HStack(spacing: 6) {
                    Text(subtitle).font(.caption).fontWeight(.medium).foregroundColor(color)
                    Circle().fill(Color.gray.opacity(0.4)).frame(width: 4, height: 4)
                    Text(count).font(.caption).foregroundColor(.gray)
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
        .padding(16).frame(width: 160, height: 160)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
