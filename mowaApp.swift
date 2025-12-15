import SwiftUI

@main
struct MowaApp: App {
    init() {
        // Запускаем проверку обновлений в фоне при старте
        ContentManager.shared.checkForUpdates()
    }
    
    var body: some Scene {
        WindowGroup {
            // БЫЛО: HomeView() -> Это открывало только одну страницу без меню
            // СТАЛО: ContentView() -> Это открывает всё приложение с вкладками
            ContentView()
        }
    }
}
