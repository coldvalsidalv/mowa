import UserNotifications
import SwiftUI

enum NotificationType: String {
    case vocabulary = "vocabulary_review"
    case grammar = "grammar_review"
    case streak = "streak_warning"
    case league = "league_overtake"
    case challenges = "new_challenges"
    case content = "new_content"
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // 1. Запрос разрешения
    func requestAuthorization(completion: (@Sendable (Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                verbumLog("❌ Ошибка авторизации уведомлений: \(error.localizedDescription)")
            } else if granted {
                verbumLog("✅ Разрешение на уведомления получено")
            } else {
                verbumLog("⚠️ Пользователь отклонил запрос на уведомления")
            }
            if let completion {
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }
    
    // 2. Универсальная функция планирования
    func scheduleNotification(type: NotificationType, title: String, body: String, timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                verbumLog("❌ Ошибка планирования \(type.rawValue): \(error.localizedDescription)")
            } else {
                verbumLog("✅ Запланировано уведомление: \(type.rawValue) через \(timeInterval) сек.")
            }
        }
    }
    
    // 3. Планирование по календарю
    func scheduleDailyNotification(type: NotificationType, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                verbumLog("❌ Ошибка планирования \(type.rawValue): \(error.localizedDescription)")
            } else {
                verbumLog("✅ Ежедневное уведомление \(type.rawValue) запланировано на \(hour):\(String(format: "%02d", minute))")
            }
        }
    }
    
    // 4. Отмена уведомлений
    func cancelNotification(type: NotificationType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [type.rawValue])
    }
    
    // 5. Обработка уведомления, когда приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - API ДЛЯ БИЗНЕС-ЛОГИКИ
extension NotificationManager {
    /// Ежедневное напоминание в выбранное юзером время (Профиль → Уведомления).
    /// Перезаписывает предыдущее расписание (одинаковый identifier).
    func scheduleDailyReminder(at time: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        scheduleDailyNotification(
            type: .vocabulary,
            title: L("notification.vocab_title"),
            body: L("notification.vocab_body"),
            hour: comps.hour ?? 9,
            minute: comps.minute ?? 0
        )
    }

    func scheduleGrammarReview() {
        scheduleNotification(type: .grammar, title: L("notification.grammar_title"), body: L("notification.grammar_body"), timeInterval: 172800)
    }

    func scheduleStreakProtection() {
        scheduleDailyNotification(type: .streak, title: L("notification.streak_title"), body: L("notification.streak_body"), hour: 20, minute: 0)
    }

    func scheduleDailyChallengeReminder() {
        scheduleNotification(type: .challenges, title: L("notification.challenges_title"), body: L("notification.challenges_body"), timeInterval: 64800)
    }

    func scheduleNewContent() {
        scheduleNotification(type: .content, title: L("notification.content_title"), body: L("notification.content_body"), timeInterval: 259200)
    }

    // MARK: - Notifications toggle (flow from Profile)

    /// Full enable flow from the UI: check status → request if needed → jump to
    /// Settings if previously denied. On success schedules the daily reminder +
    /// streak protection. `onResult(true)` — enabled and scheduled; `onResult(false)`
    /// — couldn't enable, the caller should turn the toggle back off.
    /// Encapsulates UNUserNotificationCenter/UIApplication so the VM doesn't touch them.
    func enableFromSettings(reminderTime: Date, onResult: @escaping @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.requestAuthorization { granted in
                        if granted { self.scheduleReminderWithStreak(at: reminderTime) }
                        onResult(granted)
                    }
                case .denied:
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    onResult(false)
                default:
                    self.scheduleReminderWithStreak(at: reminderTime)
                    onResult(true)
                }
            }
        }
    }

    /// Toggle off: remove all pending and delivered notifications.
    func disableAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func scheduleReminderWithStreak(at time: Date) {
        scheduleDailyReminder(at: time)
        scheduleStreakProtection()
    }
}
