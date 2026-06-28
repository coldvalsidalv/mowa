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
            title: "🇵🇱 Время заниматься польским",
            body: "Несколько минут повторения — и слова не забудутся.",
            hour: comps.hour ?? 9,
            minute: comps.minute ?? 0
        )
    }

    func scheduleGrammarReview() {
        scheduleNotification(type: .grammar, title: "📖 Грамматика ждёт", body: "Пара минут на польскую грамматику — и правила встанут на место.", timeInterval: 172800)
    }

    func scheduleStreakProtection() {
        scheduleDailyNotification(type: .streak, title: "🔥 Не дай стриму угаснуть!", body: "Пройди урок до полуночи, чтобы сохранить свою серию.", hour: 20, minute: 0)
    }

    func scheduleWeeklyChallenges() {
        scheduleNotification(type: .challenges, title: "🏆 Ежедневные вызовы ждут", body: "Задания обновлены. Выполни их и заработай XP!", timeInterval: 64800)
    }

    func scheduleNewContent() {
        scheduleNotification(type: .content, title: "🆕 Новые слова добавлены", body: "В словаре появились новые темы — иди изучай!", timeInterval: 259200)
    }
}
