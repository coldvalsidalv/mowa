import SwiftUI
import UserNotifications

// 1. Создаем AppDelegate для управления жизненным циклом уведомлений
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Назначаем делегата для уведомлений
        UNUserNotificationCenter.current().delegate = self
        
        // Запрашиваем разрешение на отправку уведомлений при старте
        NotificationManager.shared.requestAuthorization()
        
        return true
    }
    
    // Этот метод позволяет показывать уведомления (баннеры), даже если приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct MowaApp: App {
    // 2. Подключаем AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 3. Отслеживаем состояние приложения (Активно / Свернуто)
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Запускаем проверку обновлений контента
        ContentManager.shared.checkForUpdates()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 4. Логика планирования уведомлений
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // ПРИЛОЖЕНИЕ СВЕРНУТО (Игрок ушел)
                print("App went to background: Scheduling notifications")
                
                // а) Планируем напоминание о страйке на вечер (20:00)
                NotificationManager.shared.scheduleStreakProtection()
                
                // б) Планируем повторение слов через 24 часа
                NotificationManager.shared.scheduleVocabularyReview()
                
                // в) Можно запланировать рандомное напоминание о грамматике
                NotificationManager.shared.scheduleGrammarReview()
                
            case .active:
                // ПРИЛОЖЕНИЕ ОТКРЫТО (Игрок вернулся)
                print("App is active: Clearing warnings")
                
                // а) Сбрасываем счетчик на иконке приложения
                UNUserNotificationCenter.current().setBadgeCount(0)
                
                // б) Отменяем уведомление о потере страйка (ведь он уже зашел!)
                NotificationManager.shared.cancelNotification(type: .streak)
                
            default:
                break
            }
        }
    }
}
