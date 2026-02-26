import SwiftUI
import UserNotifications

@main
struct MowaApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Применение темы должно быть быстрым и синхронным, чтобы избежать моргания
        let defaults = UserDefaults.standard
        let useSystemTheme = defaults.bool(forKey: StorageKeys.useSystemTheme)
        let isDarkMode = defaults.object(forKey: StorageKeys.isDarkMode) as? Bool ?? false
        
        ThemeApplier.applyTheme(useSystemTheme: useSystemTheme, isDarkMode: isDarkMode, animated: false)
        
        // Инициализация синглтона
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Асинхронный вызов обновлений не блокирует запуск приложения
                .task {
                    ContentManager.shared.checkForUpdates()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                let nm = NotificationManager.shared
                nm.scheduleStreakProtection()
                nm.scheduleVocabularyReview()
                nm.scheduleGrammarReview()
                
            case .active:
                UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
                NotificationManager.shared.cancelNotification(type: .streak)
                
            default:
                break
            }
        }
    }
}
