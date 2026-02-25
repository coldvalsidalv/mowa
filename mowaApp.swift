import SwiftUI
import UserNotifications

// 1. AppDelegate для уведомлений
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestAuthorization()
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct MowaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        ContentManager.shared.checkForUpdates()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // ИСПРАВЛЕНО: Новый синтаксис для iOS 17+ (добавлены oldPhase и newPhase)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                print("App went to background")
                NotificationManager.shared.scheduleStreakProtection()
                NotificationManager.shared.scheduleVocabularyReview()
                NotificationManager.shared.scheduleGrammarReview()
                
            case .active:
                print("App is active")
                UNUserNotificationCenter.current().setBadgeCount(0)
                NotificationManager.shared.cancelNotification(type: .streak)
                
            default:
                break
            }
        }
    }
}
