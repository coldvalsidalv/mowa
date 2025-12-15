import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // 1. СТАРТ
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Старт")
                }
                .tag(0)
            
            // 2. УЧИТЬ (Слова и Грамматика)
            LessonsView()
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text("Учить")
                }
                .tag(1)
            
            // 3. ТРОФЕИ (Используем TrophiesView)
            LeaderboardView() // <-- НОВЫЙ ЭКРАН
                            .tabItem {
                                Image(systemName: "trophy.fill")
                                Text("Ranking")
                            }
                            .tag(2)
            
            // 4. ПРОФИЛЬ
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Профиль")
                }
                .tag(3)
        }
        .tint(.purple)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
