import SwiftUI
import SwiftData
import UserNotifications

@main
struct VerbumApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        let defaults = UserDefaults.standard
        let useSystemTheme = defaults.bool(forKey: StorageKeys.useSystemTheme)
        let isDarkMode = defaults.object(forKey: StorageKeys.isDarkMode) as? Bool ?? false

        ThemeApplier.applyTheme(useSystemTheme: useSystemTheme, isDarkMode: isDarkMode, animated: false)
        _ = NotificationManager.shared
        _ = LanguageManager.shared  // initializes the language bundle at launch
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Initialize the local database (SwiftData)
        .modelContainer(for: [VocabItem.self, ReviewLog.self, GrammarProgress.self, WritingAttempt.self])
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // ... notifications logic
        }
    }
}
