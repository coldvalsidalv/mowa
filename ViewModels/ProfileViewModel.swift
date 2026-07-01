import SwiftUI
import SwiftData
import Combine

final class ProfileViewModel: ObservableObject {
    @AppStorage(StorageKeys.userName) var userName: String = ""
    @AppStorage(StorageKeys.userEmail) var userEmail: String = ""
    /// Source of truth — the DB. Populated by loadStats(context:).
    /// "Known" threshold: stability ≥ 3 days (see CLAUDE.md).
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

    // 7-day activity — populated from ReviewLog via loadActivity()
    @Published var activityData: [ActivityData] = []

    /// Achievements cache. Recomputed via recomputeAchievements() — called
    /// from loadStats/loadActivity/resetAllProgress. It used to be a computed property,
    /// which rebuilt 15 structs on every body re-render.
    ///
    /// ⚠️ CONTRACT: if you add a new code path that mutates
    /// totalLearnedWords / userXP / dayStreak / completedGrammarLessons —
    /// you must call recomputeAchievements() right after. Otherwise the UI
    /// shows stale achievements until the next .onAppear.
    @Published var achievements: [Achievement] = []

    /// Total grammar lessons — threshold for the "Профессор" achievement.
    /// The old hardcoded value (20) diverged from actual content (6 lessons),
    /// making the achievement unreachable — computed dynamically instead.
    /// `static` so the bundle read happens once per process, not once per
    /// ProfileViewModel instance.
    private static var totalGrammarLessonsCache = DataManager.shared.loadGrammar().count
    private var totalGrammarLessons: Int { Self.totalGrammarLessonsCache }

    init() {
        recomputeAchievements()
    }

    /// Refreshes the lesson total from the API (falls back to the bundle) so the
    /// "Профессор" threshold can't drift from what LessonsView actually shows if the
    /// backend ships a different lesson count than what's bundled in this build.
    func refreshGrammarLessonsTotal() async {
        let count = await DataManager.shared.loadGrammarAsync().count
        guard count > 0, count != Self.totalGrammarLessonsCache else { return }
        Self.totalGrammarLessonsCache = count
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
            grammar: completedGrammarCount,
            totalGrammarLessons: totalGrammarLessons
        )
    }

    /// Pure achievement factory — no instance state, testable without constructing
    /// ProfileViewModel (whose isolated deinit crashes XCTest under Swift 6).
    ///
    /// Threshold achievements are described as data (`achievementSpecs`) and built by
    /// a single mapping: adding one = one row in the list, no logic change (OCP).
    /// The composite "Разносторонний" doesn't fit the single-metric model and is added explicitly.
    nonisolated static func makeAchievements(
        totalLearnedWords: Int,
        dayStreak: Int,
        userXP: Int,
        grammar: Int,
        totalGrammarLessons: Int
    ) -> [Achievement] {
        func metricValue(_ metric: AchievementMetric) -> Int {
            switch metric {
            case .words:   return totalLearnedWords
            case .streak:  return dayStreak
            case .xp:      return userXP
            case .grammar: return grammar
            }
        }
        func resolvedThreshold(_ threshold: AchievementThreshold) -> Int {
            switch threshold {
            case .fixed(let count):    return count
            case .totalGrammarLessons: return totalGrammarLessons
            }
        }

        var result = achievementSpecs.map { spec -> Achievement in
            let currentValue = metricValue(spec.metric)
            let threshold = resolvedThreshold(spec.threshold)
            // threshold == 0 only happens for "Профессор" while the lesson list isn't
            // loaded yet — then the achievement is locked (as in the original guard logic).
            let unlocked = threshold > 0 && currentValue >= threshold
            let progress = threshold > 0 ? min(Double(currentValue) / Double(threshold), 1.0) : 0
            return Achievement(
                title: spec.title,
                description: spec.description,
                icon: spec.icon,
                color: spec.color,
                unlocked: unlocked,
                progress: progress,
                progressLabel: "\(currentValue) / \(threshold) \(spec.unit)"
            )
        }

        // ── Special: the composite achievement doesn't reduce to a single metric ──
        result.append(
            Achievement(
                title: "Разносторонний",
                description: "50 слов и 3 урока грамматики",
                icon: "square.grid.2x2.fill",
                color: .mint,
                unlocked: totalLearnedWords >= 50 && grammar >= 3,
                progress: min(Double(min(totalLearnedWords, 50)) / 50 * 0.5 + Double(min(grammar, 3)) / 3 * 0.5, 1.0),
                progressLabel: totalLearnedWords < 50 ? "\(totalLearnedWords) / 50 слов" : "\(grammar) / 3 урока"
            )
        )
        return result
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

    // MARK: - Stats from DB

    /// Counts learned words (stability ≥ 3 days) directly from the DB.
    /// Call in .onAppear: after sessions the counter updates itself.
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
            let xp = dayLogs.count * 5 // ~5 XP per card
            let label = formatter.string(from: day).capitalized
            return ActivityData(day: label, xp: xp)
        }
    }


    // MARK: - Actions

    func toggleNotifications(_ isEnabled: Bool) {
        if isEnabled {
            let time = Date(timeIntervalSince1970: notificationTimeInterval)
            NotificationManager.shared.enableFromSettings(reminderTime: time) { [weak self] didEnable in
                if !didEnable { self?.notificationsEnabled = false }
            }
        } else {
            NotificationManager.shared.disableAll()
        }
    }

    func resetAllProgress() {
        userXP = 0
        dayStreak = 0
        UserDefaults.standard.removeObject(forKey: StorageKeys.completedGrammarLessons)
        UserDefaults.standard.removeObject(forKey: StorageKeys.currentChallenges)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastChallengeDate)
        // totalLearnedWords reflects the DB and will refresh from loadStats on the next onAppear.
        // We deliberately don't reset FSRS card progress — that's a destructive operation.
        recomputeAchievements()
    }

    /// Deletes the account (network + sign-out live in AccountService), then clears the
    /// local profile. On a network error we clear nothing — the user stays logged in and sees an alert.
    func deleteAccount() async {
        do {
            try await AccountService.shared.deleteAccount()
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

// MARK: - Achievement specs (data, not code)

/// Progress metric a threshold achievement is bound to.
private enum AchievementMetric {
    case words, streak, xp, grammar
}

/// Unlock threshold: fixed, or dynamic (the grammar lesson count).
private enum AchievementThreshold {
    case fixed(Int)
    case totalGrammarLessons
}

/// Declarative description of a threshold achievement. Adding a new achievement is
/// a new element in `achievementSpecs`, not an edit to `makeAchievements` (OCP).
private struct AchievementSpec {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let metric: AchievementMetric
    let threshold: AchievementThreshold
    let unit: String   // suffix for progressLabel: "слов" / "дней" / "XP" / "уроков"
}

/// Immutable Sendable constant — read from the nonisolated `makeAchievements`.
private let achievementSpecs: [AchievementSpec] = [
    // ── Vocabulary ──────────────────────────────────────────
    .init(title: "Первое слово", description: "Выучи своё первое слово",
          icon: "hand.raised.fill", color: .blue, metric: .words, threshold: .fixed(1), unit: "слово"),
    .init(title: "Десятка", description: "Выучи 10 слов",
          icon: "sparkles", color: .cyan, metric: .words, threshold: .fixed(10), unit: "слов"),
    .init(title: "Сотня", description: "Выучи 100 слов",
          icon: "graduationcap.fill", color: .indigo, metric: .words, threshold: .fixed(100), unit: "слов"),
    .init(title: "Полиглот", description: "Выучи 500 слов",
          icon: "globe.europe.africa.fill", color: .green, metric: .words, threshold: .fixed(500), unit: "слов"),
    .init(title: "Мастер слов", description: "Выучи 2000 слов",
          icon: "crown.fill", color: .yellow, metric: .words, threshold: .fixed(2000), unit: "слов"),
    // ── Day streak ───────────────────────────────────────────────
    .init(title: "Привычка", description: "3 дня занятий подряд",
          icon: "flame", color: .orange, metric: .streak, threshold: .fixed(3), unit: "дня"),
    .init(title: "Огонь", description: "7 дней занятий подряд",
          icon: "flame.fill", color: .red, metric: .streak, threshold: .fixed(7), unit: "дней"),
    .init(title: "Несгораемый", description: "30 дней занятий подряд",
          icon: "bolt.fill", color: .pink, metric: .streak, threshold: .fixed(30), unit: "дней"),
    // ── Experience (XP) ──────────────────────────────────────────
    .init(title: "Первые очки", description: "Набери 100 XP",
          icon: "star.fill", color: .blue, metric: .xp, threshold: .fixed(100), unit: "XP"),
    .init(title: "Чемпион", description: "Набери 1000 XP",
          icon: "trophy.fill", color: .orange, metric: .xp, threshold: .fixed(1000), unit: "XP"),
    .init(title: "Легенда", description: "Набери 5000 XP",
          icon: "medal.fill", color: .purple, metric: .xp, threshold: .fixed(5000), unit: "XP"),
    // ── Grammar ────────────────────────────────────────────────
    .init(title: "Первый урок", description: "Пройди первый урок грамматики",
          icon: "pencil.and.list.clipboard", color: .teal, metric: .grammar, threshold: .fixed(1), unit: "урок"),
    .init(title: "Грамматик", description: "Пройди 5 уроков грамматики",
          icon: "text.book.closed.fill", color: .green, metric: .grammar, threshold: .fixed(5), unit: "уроков"),
    .init(title: "Профессор", description: "Пройди все уроки грамматики",
          icon: "brain.head.profile", color: .purple, metric: .grammar, threshold: .totalGrammarLessons, unit: "уроков"),
]
