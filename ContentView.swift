import SwiftUI

// MARK: - Root: онбординг или основной экран

struct RootView: View {
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    // Подписка на смену языка — перерисовывает TabView с новыми строками
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(L("tab.home"))
                }
                .tag(0)

            LessonsView()
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
        // Перерисовываем при смене языка
        .id(languageManager.currentLanguage)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
