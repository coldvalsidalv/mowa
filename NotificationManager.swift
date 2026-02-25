import UserNotifications
import SwiftUI

// Типы уведомлений (для удобства управления)
enum NotificationType: String {
    case vocabulary = "vocabulary_review"
    case grammar = "grammar_review"
    case streak = "streak_warning"
    case league = "league_overtake"
    case challenges = "new_challenges"
    case content = "new_content"
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // 1. Запрос разрешения на уведомления
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Разрешение на уведомления получено")
            } else if let error = error {
                print("Ошибка авторизации: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Универсальная функция планирования
    func scheduleNotification(type: NotificationType, title: String, body: String, timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Триггер по времени (через сколько секунд сработает)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Уникальный ID, чтобы можно было отменить конкретное уведомление
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка планирования: \(error)")
            }
        }
    }
    
    // 3. Планирование по календарю (например, каждый день в 20:00)
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
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // 4. Отмена уведомлений (например, если юзер уже зашел в приложение)
    func cancelNotification(type: NotificationType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [type.rawValue])
    }
    
    // 5. Обработка уведомления, когда приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Показываем баннер даже если приложение открыто
        completionHandler([.banner, .sound])
    }
}

// MARK: - API ДЛЯ БИЗНЕС-ЛОГИКИ
extension NotificationManager {
    
    // Сценарий 1: "Повторить слова" (Интервальное повторение)
    func scheduleVocabularyReview() {
        // Напоминаем через 24 часа
        scheduleNotification(
            type: .vocabulary,
            title: "🧠 Время повторить слова",
            body: "5 слов готовы к повторению. Не дай им забыться!",
            timeInterval: 24 * 60 * 60 // 24 часа
        )
    }
    
    // Сценарий 2: "Повторить грамматику"
    func scheduleGrammarReview() {
        // Напоминаем через 48 часов
        scheduleNotification(
            type: .grammar,
            title: "📖 Грамматика ждет",
            body: "Давай освежим правило Past Simple за 2 минуты?",
            timeInterval: 48 * 60 * 60
        )
    }
    
    // Сценарий 3: "Потеря страйка" (КРИТИЧНОЕ)
    // Эту функцию нужно вызывать каждый раз, когда юзер закрывает приложение
    func scheduleStreakProtection() {
        // Ставим напоминание на завтра на 20:00
        scheduleDailyNotification(
            type: .streak,
            title: "🔥 Ой-ой, страйк горит!",
            body: "Пройди урок до полуночи, чтобы сохранить серию 5 дней!",
            hour: 20,
            minute: 00
        )
    }
    
    // Сценарий 4: "Обошли в лиге"
    // В реальности это Push Notification с сервера, но вот имитация локально
    func simulateLeagueOvertake() {
        scheduleNotification(
            type: .league,
            title: "🛡️ Вас обошли в лиге!",
            body: "Marek W. вырвался вперед. Верни себе 3-е место!",
            timeInterval: 5 // Через 5 секунд для теста
        )
    }
    
    // Сценарий 5: "Новые челленджи"
    func scheduleWeeklyChallenges() {
        // Например, каждое утро понедельника (логика календаря может быть сложнее)
        scheduleNotification(
            type: .challenges,
            title: "🏆 Новые челленджи",
            body: "Недельные задания обновлены. Заработай х2 XP!",
            timeInterval: 7 * 24 * 60 * 60 // Раз в неделю
        )
    }
    
    // Сценарий 6: "Новый контент"
    func scheduleNewContent() {
        scheduleNotification(
            type: .content,
            title: "🆕 Доступен новый курс",
            body: "Открыта тема 'Путешествия'. Поехали?",
            timeInterval: 3 * 24 * 60 * 60 // Раз в 3 дня
        )
    }
}
