import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // ВКЛАДКА 1: Главная
            HomeView()
                .tabItem {
                    Label("Start", systemImage: "house.fill")
                }
            
            // ВКЛАДКА 2: Уроки (Новый экран)
            LessonsView()
                .tabItem {
                    Label("Lekcje", systemImage: "book.closed.fill")
                }
            
            // ВКЛАДКА 3: Трофеи (Пока заглушка или Викторина)
            QuizView() // Можно временно поставить сюда Викторину
                .tabItem {
                    Label("Trofea", systemImage: "trophy.fill")
                }
            
            // ВКЛАДКА 4: Профиль (Настройки)
            SettingsView()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        // Цвет активной иконки (как на скрине - синий)
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
}
