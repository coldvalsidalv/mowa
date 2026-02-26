import SwiftUI
import UserNotifications
import Combine

final class ProfileViewModel: ObservableObject {
    @AppStorage(StorageKeys.userName) var userName: String = "Uladzislau Kisialiou"
    @AppStorage(StorageKeys.userEmail) var userEmail: String = "uladzislaukisialiou@gmail.com"
    @AppStorage(StorageKeys.totalLearnedWords) var totalLearnedWords: Int = 142
    @AppStorage(StorageKeys.dayStreak) var dayStreak: Int = 5
    @AppStorage(StorageKeys.dailyGoal) var dailyGoal: Int = 10
    @AppStorage(StorageKeys.userXP) var userXP: Int = 1250
    
    @AppStorage(StorageKeys.isDarkMode) var isDarkMode: Bool = false
    @AppStorage(StorageKeys.useSystemTheme) var useSystemTheme: Bool = true
    @AppStorage(StorageKeys.appLanguage) var appLanguage: String = "Ru"
    @AppStorage(StorageKeys.notificationsEnabled) var notificationsEnabled: Bool = false
    @AppStorage(StorageKeys.notificationTime) var notificationTimeInterval: Double = 32400
    
    @Published var showDeleteAlert = false
    @Published var showResetAlert = false
    @Published var showAchievementsDetail = false
    
    let activityData: [ActivityData] = [
        .init(day: "Пн", xp: 40), .init(day: "Вт", xp: 65), .init(day: "Ср", xp: 30),
        .init(day: "Чт", xp: 90), .init(day: "Пт", xp: 55), .init(day: "Сб", xp: 120),
        .init(day: "Вс", xp: 80)
    ]
    
    let achievements: [Achievement] = [
        .init(title: "Первые шаги", description: "Завершите первый урок без ошибок", icon: "shoe.fill", color: .blue, unlocked: true),
        .init(title: "Огонь", description: "Поддерживайте серию 7 дней подряд", icon: "flame.fill", color: .orange, unlocked: true),
        .init(title: "Полиглот", description: "Выучите 500 новых слов", icon: "globe.europe.africa.fill", color: .green, unlocked: false),
        .init(title: "Ночная сова", description: "Пройдите урок после 23:00", icon: "moon.stars.fill", color: .purple, unlocked: false)
    ]
    
    var notificationTimeBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: self.notificationTimeInterval) },
            set: { self.notificationTimeInterval = $0.timeIntervalSince1970 }
        )
    }
    
    func toggleNotifications(_ isEnabled: Bool) {
        if isEnabled {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        NotificationManager.shared.requestAuthorization()
                    case .denied:
                        self.notificationsEnabled = false
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    case .authorized, .provisional, .ephemeral:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    func resetAllProgress() {
        userXP = 0
        totalLearnedWords = 0
        dayStreak = 0
        UserDefaults.standard.removeObject(forKey: StorageKeys.completedGrammarLessons)
        UserDefaults.standard.removeObject(forKey: StorageKeys.completedChallengeIDs)
    }
    
    func deleteAccount() {
        resetAllProgress()
        userName = ""
        userEmail = ""
        notificationsEnabled = false
        AvatarManager.shared.deleteAvatar()
    }
}
