import SwiftUI
import SwiftData
import UserNotifications
import Combine

final class ProfileViewModel: ObservableObject {
    @AppStorage(StorageKeys.userName) var userName: String = ""
    @AppStorage(StorageKeys.userEmail) var userEmail: String = ""
    /// Source of truth — БД. Заполняется loadStats(context:).
    /// Порог «знаю»: stability ≥ 3 дня (см. CLAUDE.md).
    @Published var totalLearnedWords: Int = 0
    @AppStorage(StorageKeys.dayStreak) var dayStreak: Int = 0
    @AppStorage(StorageKeys.dailyGoal) var dailyGoal: Int = 10
    @AppStorage(StorageKeys.userXP) var userXP: Int = 0

    @AppStorage(StorageKeys.isDarkMode) var isDarkMode: Bool = false
    @AppStorage(StorageKeys.useSystemTheme) var useSystemTheme: Bool = true
    @AppStorage(StorageKeys.appLanguage) var appLanguage: String = "ru"
    @AppStorage(StorageKeys.notificationsEnabled) var notificationsEnabled: Bool = false
    @AppStorage(StorageKeys.notificationTime) var notificationTimeInterval: Double = 32400

    @Published var showResetAlert = false
    @Published var showDeleteAccountAlert = false
    @Published var accountDeletionError: String?

    // Активность за 7 дней — заполняется из ReviewLog через loadActivity()
    @Published var activityData: [ActivityData] = []

    /// Кэш достижений. Пересчитывается через recomputeAchievements() — вызывается
    /// из loadStats/loadActivity/resetAllProgress. Раньше был computed property,
    /// что пересоздавало 15 структур на каждый body re-render.
    ///
    /// ⚠️ КОНТРАКТ: если ты добавляешь новый код-путь, который мутирует
    /// totalLearnedWords / userXP / dayStreak / completedGrammarLessons —
    /// обязан вызвать recomputeAchievements() сразу после. Иначе UI
    /// показывает stale ачивки до следующего .onAppear.
    @Published var achievements: [Achievement] = []

    init() {
        recomputeAchievements()
    }

    var completedGrammarCount: Int {
        (UserDefaults.standard.stringArray(forKey: StorageKeys.completedGrammarLessons) ?? []).count
    }

    func recomputeAchievements() {
        achievements = Self.makeAchievements(
            totalLearnedWords: totalLearnedWords,
            dayStreak: dayStreak,
            userXP: userXP,
            grammar: completedGrammarCount
        )
    }

    /// Чистая фабрика достижений — без instance-state, тестируема без создания
    /// ProfileViewModel (что под Swift 6 isolated deinit крашит XCTest).
    nonisolated static func makeAchievements(
        totalLearnedWords: Int,
        dayStreak: Int,
        userXP: Int,
        grammar: Int
    ) -> [Achievement] {
        [
            // ── Словарный запас ──────────────────────────────────────────
            .init(
                title: "Первое слово",
                description: "Выучи своё первое слово",
                icon: "hand.raised.fill",
                color: .blue,
                unlocked: totalLearnedWords >= 1,
                progress: min(Double(totalLearnedWords) / 1, 1.0),
                progressLabel: "\(totalLearnedWords) / 1 слово"
            ),
            .init(
                title: "Десятка",
                description: "Выучи 10 слов",
                icon: "sparkles",
                color: .cyan,
                unlocked: totalLearnedWords >= 10,
                progress: min(Double(totalLearnedWords) / 10, 1.0),
                progressLabel: "\(totalLearnedWords) / 10 слов"
            ),
            .init(
                title: "Сотня",
                description: "Выучи 100 слов",
                icon: "graduationcap.fill",
                color: .indigo,
                unlocked: totalLearnedWords >= 100,
                progress: min(Double(totalLearnedWords) / 100, 1.0),
                progressLabel: "\(totalLearnedWords) / 100 слов"
            ),
            .init(
                title: "Полиглот",
                description: "Выучи 500 слов",
                icon: "globe.europe.africa.fill",
                color: .green,
                unlocked: totalLearnedWords >= 500,
                progress: min(Double(totalLearnedWords) / 500, 1.0),
                progressLabel: "\(totalLearnedWords) / 500 слов"
            ),
            .init(
                title: "Мастер слов",
                description: "Выучи 2000 слов",
                icon: "crown.fill",
                color: .yellow,
                unlocked: totalLearnedWords >= 2000,
                progress: min(Double(totalLearnedWords) / 2000, 1.0),
                progressLabel: "\(totalLearnedWords) / 2000 слов"
            ),
            // ── Серия дней ───────────────────────────────────────────────
            .init(
                title: "Привычка",
                description: "3 дня занятий подряд",
                icon: "flame",
                color: .orange,
                unlocked: dayStreak >= 3,
                progress: min(Double(dayStreak) / 3, 1.0),
                progressLabel: "\(dayStreak) / 3 дня"
            ),
            .init(
                title: "Огонь",
                description: "7 дней занятий подряд",
                icon: "flame.fill",
                color: .red,
                unlocked: dayStreak >= 7,
                progress: min(Double(dayStreak) / 7, 1.0),
                progressLabel: "\(dayStreak) / 7 дней"
            ),
            .init(
                title: "Несгораемый",
                description: "30 дней занятий подряд",
                icon: "bolt.fill",
                color: .pink,
                unlocked: dayStreak >= 30,
                progress: min(Double(dayStreak) / 30, 1.0),
                progressLabel: "\(dayStreak) / 30 дней"
            ),
            // ── Опыт ─────────────────────────────────────────────────────
            .init(
                title: "Первые очки",
                description: "Набери 100 XP",
                icon: "star.fill",
                color: .blue,
                unlocked: userXP >= 100,
                progress: min(Double(userXP) / 100, 1.0),
                progressLabel: "\(userXP) / 100 XP"
            ),
            .init(
                title: "Чемпион",
                description: "Набери 1000 XP",
                icon: "trophy.fill",
                color: .orange,
                unlocked: userXP >= 1000,
                progress: min(Double(userXP) / 1000, 1.0),
                progressLabel: "\(userXP) / 1000 XP"
            ),
            .init(
                title: "Легенда",
                description: "Набери 5000 XP",
                icon: "medal.fill",
                color: .purple,
                unlocked: userXP >= 5000,
                progress: min(Double(userXP) / 5000, 1.0),
                progressLabel: "\(userXP) / 5000 XP"
            ),
            // ── Грамматика ────────────────────────────────────────────────
            .init(
                title: "Первый урок",
                description: "Пройди первый урок грамматики",
                icon: "pencil.and.list.clipboard",
                color: .teal,
                unlocked: grammar >= 1,
                progress: min(Double(grammar) / 1, 1.0),
                progressLabel: "\(grammar) / 1 урок"
            ),
            .init(
                title: "Грамматик",
                description: "Пройди 5 уроков грамматики",
                icon: "text.book.closed.fill",
                color: .green,
                unlocked: grammar >= 5,
                progress: min(Double(grammar) / 5, 1.0),
                progressLabel: "\(grammar) / 5 уроков"
            ),
            .init(
                title: "Профессор",
                description: "Пройди все уроки грамматики",
                icon: "brain.head.profile",
                color: .purple,
                unlocked: grammar >= 20,
                progress: min(Double(grammar) / 20, 1.0),
                progressLabel: "\(grammar) / 20 уроков"
            ),
            // ── Особые ───────────────────────────────────────────────────
            .init(
                title: "Разносторонний",
                description: "50 слов и 3 урока грамматики",
                icon: "square.grid.2x2.fill",
                color: .mint,
                unlocked: totalLearnedWords >= 50 && grammar >= 3,
                progress: min(Double(min(totalLearnedWords, 50)) / 50 * 0.5 + Double(min(grammar, 3)) / 3 * 0.5, 1.0),
                progressLabel: totalLearnedWords < 50 ? "\(totalLearnedWords) / 50 слов" : "\(grammar) / 3 урока"
            ),
        ]
    }

    var notificationTimeBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: self.notificationTimeInterval) },
            set: {
                self.notificationTimeInterval = $0.timeIntervalSince1970
                if self.notificationsEnabled {
                    NotificationManager.shared.scheduleDailyReminder(at: $0)
                }
            }
        )
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var displayName: String {
        userName.isEmpty ? "Пользователь" : userName
    }

    var currentLeague: UserLeague {
        UserLeague.determineLeague(for: userXP)
    }

    var currentLeagueTitle: String {
        currentLeague.title
    }

    // MARK: - Stats from DB

    /// Считает выученные слова (stability ≥ 3 дня) напрямую из БД.
    /// Вызывать в .onAppear: после сессий счётчик обновится сам.
    func loadStats(context: ModelContext) {
        let threshold = 3.0
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.fsrsData.stability >= threshold }
        )
        totalLearnedWords = (try? context.fetchCount(descriptor)) ?? 0
        recomputeAchievements()
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


    // MARK: - Actions

    func toggleNotifications(_ isEnabled: Bool) {
        if isEnabled {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        NotificationManager.shared.requestAuthorization { granted in
                            if granted {
                                self.scheduleDailyReminder()
                            } else {
                                self.notificationsEnabled = false
                            }
                        }
                    case .denied:
                        self.notificationsEnabled = false
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    default:
                        self.scheduleDailyReminder()
                    }
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }

    private func scheduleDailyReminder() {
        let time = Date(timeIntervalSince1970: notificationTimeInterval)
        NotificationManager.shared.scheduleDailyReminder(at: time)
        NotificationManager.shared.scheduleStreakProtection()
    }

    func resetAllProgress() {
        userXP = 0
        dayStreak = 0
        UserDefaults.standard.removeObject(forKey: StorageKeys.completedGrammarLessons)
        UserDefaults.standard.removeObject(forKey: StorageKeys.currentChallenges)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastChallengeDate)
        // totalLearnedWords отражает БД и обновится из loadStats при следующем onAppear.
        // Сброс прогресса FSRS-карточек намеренно не делаем — это разрушительная операция.
        recomputeAchievements()
    }

    /// Удаляет аккаунт на бэкенде, затем разлогинивает и чистит локальный профиль.
    /// При ошибке сети ничего не чистим — юзер остаётся залогинен и видит alert.
    func deleteAccount() async {
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else {
            // Сессии нет — удалять на сервере нечего, просто чистим локально.
            AuthManager.shared.signOut()
            clearLocalProfile()
            return
        }
        do {
            try await APIClient.shared.deleteAccount(userId: userId)
            AuthManager.shared.signOut()
            clearLocalProfile()
        } catch {
            accountDeletionError = "Не удалось удалить аккаунт. Проверь соединение и попробуй ещё раз."
        }
    }

    private func clearLocalProfile() {
        resetAllProgress()
        userName = ""
        userEmail = ""
        notificationsEnabled = false
        AvatarManager.shared.deleteAvatar()
    }
}
