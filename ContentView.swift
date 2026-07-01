import SwiftUI
import SwiftData
import Charts

// MARK: - Root: онбординг или основной экран

struct RootView: View {
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(StorageKeys.isDarkMode) private var isDarkMode = false
    @AppStorage(StorageKeys.useSystemTheme) private var useSystemTheme = true
    @ObservedObject private var auth = AuthManager.shared

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if !auth.isAuthenticated {
                AuthView()
            } else {
                ContentView()
            }
        }
        .preferredColorScheme(useSystemTheme ? nil : (isDarkMode ? .dark : .light))
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var triggerLessonsEditMode = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    // Подписка на смену языка — перерисовывает таб-бар (заголовки табов) с новыми строками
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack {
            // Прогрев Charts: первая инициализация фреймворка тяжёлая (~200–500 ms),
            // если делать её при открытии ProfileView. Кладём невидимый Chart в корне,
            // чтобы SwiftUI инициализировал фреймворк один раз при старте приложения.
            ChartsWarmup()

            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab, triggerLessonsEditMode: $triggerLessonsEditMode)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(L("tab.home"))
                }
                .tag(0)

            LessonsView(triggerEditMode: $triggerLessonsEditMode)
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text(L("tab.learn"))
                }
                .tag(1)

            LeaderboardView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text(L("tab.ranking"))
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text(L("tab.profile"))
                }
                .tag(3)
        }
        .tint(.purple)
        .onAppear {
            ReviewLogSyncService.shared.syncIfNeeded(context: modelContext)
            FSRSParamStore.shared.refreshIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                StreakManager.shared.refreshDayRollover()
                ReviewLogSyncService.shared.syncIfNeeded(context: modelContext)
                FSRSParamStore.shared.refreshIfNeeded()
                LeaderboardSyncService.shared.syncIfNeeded()
            }
        }
    }
}

/// Скрытый Chart для one-time прогрева Charts framework при старте.
/// Без этого первое открытие ProfileView лагает на ~200–500 ms.
private struct ChartsWarmup: View {
    @State private var done = false

    var body: some View {
        Group {
            if !done {
                Chart {
                    BarMark(x: .value("x", "0"), y: .value("y", 1))
                }
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
                .onAppear {
                    DispatchQueue.main.async { done = true }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
