import SwiftUI
import SwiftData
import UserNotifications
import Combine

final class ProfileViewModel: ObservableObject {
    @AppStorage(StorageKeys.userName) var userName: String = ""
    @AppStorage(StorageKeys.userEmail) var userEmail: String = ""
    @AppStorage(StorageKeys.totalLearnedWords) var totalLearnedWords: Int = 0
    @AppStorage(StorageKeys.dayStreak) var dayStreak: Int = 0
    @AppStorage(StorageKeys.dailyGoal) var dailyGoal: Int = 10
    @AppStorage(StorageKeys.userXP) var userXP: Int = 0

    @AppStorage(StorageKeys.isDarkMode) var isDarkMode: Bool = false
    @AppStorage(StorageKeys.useSystemTheme) var useSystemTheme: Bool = true
    @AppStorage(StorageKeys.appLanguage) var appLanguage: String = "ru"
    @AppStorage(StorageKeys.notificationsEnabled) var notificationsEnabled: Bool = false
    @AppStorage(StorageKeys.notificationTime) var notificationTimeInterval: Double = 32400

    @Published var showDeleteAlert = false
    @Published var showResetAlert = false
    @Published var showAchievementsDetail = false

    // Активность за 7 дней — заполняется из ReviewLog через loadActivity()
    @Published var activityData: [ActivityData] = []

    // Достижения — вычисляются на основе реального прогресса
    var achievements: [Achievement] {
        [
            .init(
                title: "Первые шаги",
                description: "Изучи первое слово",
                icon: "shoe.fill",
                color: .blue,
                unlocked: totalLearnedWords > 0
            ),
            .init(
                title: "Огонь",
                description: "Серия 7 дней подряд",
                icon: "flame.fill",
                color: .orange,
                unlocked: dayStreak >= 7
            ),
            .init(
                title: "Полиглот",
                description: "Выучи 500 слов",
                icon: "globe.europe.africa.fill",
                color: .green,
                unlocked: totalLearnedWords >= 500
            ),
            .init(
                title: "Чемпион",
                description: "Набери 1000 XP",
                icon: "trophy.fill",
                color: .yellow,
                unlocked: userXP >= 1000
            ),
        ]
    }

    var notificationTimeBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: self.notificationTimeInterval) },
            set: { self.notificationTimeInterval = $0.timeIntervalSince1970 }
        )
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var currentLeagueTitle: String {
        UserLeague.determineLeague(for: userXP).title
    }

    // MARK: - Activity from ReviewLog

    func loadActivity(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).reversed().map { offset -> Date in
            calendar.date(byAdding: .day, value: -offset, to: today)!
        }

        let weekAgo = days.first!
        let descriptor = FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.reviewDate >= weekAgo }
        )
        let logs = (try? context.fetch(descriptor)) ?? []

        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        formatter.locale = Locale(identifier: "ru_RU")

        activityData = days.map { day in
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayLogs = logs.filter { $0.reviewDate >= day && $0.reviewDate < nextDay }
            let xp = dayLogs.count * 5 // ~5 XP за карточку
            let label = formatter.string(from: day).capitalized
            return ActivityData(day: label, xp: xp)
        }
    }

    /// Пересчитывает totalLearnedWords из SwiftData — source of truth.
    /// Вызывается из ProfileView.onAppear чтобы синхронизировать AppStorage с реальными данными.
    func refreshLearnedCount(context: ModelContext) {
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.fsrsData.reps > 0 }
        )
        let count = (try? context.fetch(descriptor))?.count ?? 0
        if count != totalLearnedWords {
            totalLearnedWords = count
        }
    }

    // MARK: - Actions

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
                    default: break
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
