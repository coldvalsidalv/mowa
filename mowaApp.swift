import SwiftUI
import SwiftData
import UserNotifications

@main
struct MowaApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        let defaults = UserDefaults.standard
        let useSystemTheme = defaults.bool(forKey: StorageKeys.useSystemTheme)
        let isDarkMode = defaults.object(forKey: StorageKeys.isDarkMode) as? Bool ?? false
        
        ThemeApplier.applyTheme(useSystemTheme: useSystemTheme, isDarkMode: isDarkMode, animated: false)
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Инициализация локальной базы данных (SwiftData)
        .modelContainer(for: [VocabItem.self, ReviewLog.self])
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // ... логика уведомлений
        }
    }
}
