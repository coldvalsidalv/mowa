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
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Ошибка авторизации уведомлений: \(error.localizedDescription)")
            } else if granted {
                print("✅ Разрешение на уведомления получено")
            } else {
                print("⚠️ Пользователь отклонил запрос на уведомления")
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
                print("❌ Ошибка планирования \(type.rawValue): \(error.localizedDescription)")
            } else {
                print("✅ Запланировано уведомление: \(type.rawValue) через \(timeInterval) сек.")
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
                print("❌ Ошибка планирования \(type.rawValue): \(error.localizedDescription)")
            } else {
                print("✅ Ежедневное уведомление \(type.rawValue) запланировано на \(hour):\(String(format: "%02d", minute))")
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
    func scheduleVocabularyReview() {
        scheduleNotification(type: .vocabulary, title: "🧠 Время повторить слова", body: "5 слов готовы к повторению. Не дай им забыться!", timeInterval: 86400)
    }
    
    func scheduleGrammarReview() {
        scheduleNotification(type: .grammar, title: "📖 Грамматика ждет", body: "Давай освежим правило Past Simple за 2 минуты?", timeInterval: 172800)
    }
    
    func scheduleStreakProtection() {
        scheduleDailyNotification(type: .streak, title: "🔥 Ой-ой, страйк горит!", body: "Пройди урок до полуночи, чтобы сохранить серию 5 дней!", hour: 20, minute: 00)
    }
    
    func simulateLeagueOvertake() {
        scheduleNotification(type: .league, title: "🛡️ Вас обошли в лиге!", body: "Marek W. вырвался вперед. Верни себе 3-е место!", timeInterval: 5)
    }
    
    func scheduleWeeklyChallenges() {
        scheduleNotification(type: .challenges, title: "🏆 Новые челленджи", body: "Недельные задания обновлены. Заработай х2 XP!", timeInterval: 604800)
    }
    
    func scheduleNewContent() {
        scheduleNotification(type: .content, title: "🆕 Доступен новый курс", body: "Открыта тема 'Путешествия'. Поехали?", timeInterval: 259200)
    }
}
