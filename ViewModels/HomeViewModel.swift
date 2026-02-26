import SwiftUI
import SwiftData
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var userXP: Int = 0
    @Published var wordsLearnedToday: Int = 0
    @Published var dailyWordGoal: Int = 10
    @Published var challenges: [DailyChallenge] = []
    @Published var showAllCompletedMessage = false
    
    private var lastUpdateDate: String = ""
    private let calendar = Calendar.current
    
    var currentLeague: UserLeague {
        UserLeague.determineLeague(for: userXP)
    }
    
    var dailyGoalProgress: Double {
        guard dailyWordGoal > 0 else { return 0 }
        return min(Double(wordsLearnedToday) / Double(dailyWordGoal), 1.0)
    }
    
    var isDailyGoalCompleted: Bool {
        wordsLearnedToday >= dailyWordGoal
    }
    
    init() {
        self.userXP = UserDefaults.standard.integer(forKey: StorageKeys.userXP)
        loadDailyState()
    }
    
    /// Основной метод синхронизации UI с реальной базой данных.
    /// Вызывается из .onAppear в HomeView.
    func refreshStats(context: ModelContext) {
        checkAndResetDailyStateIfNeeded()
        
        let startOfDay = calendar.startOfDay(for: Date())
        
        // Запрос всех логов за сегодня
        let descriptor = FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.reviewDate >= startOfDay }
        )
        
        do {
            let todaysLogs = try context.fetch(descriptor)
            // Считаем уникальные карточки, которые были изучены сегодня
            let uniqueCards = Set(todaysLogs.map { $0.cardId })
            self.wordsLearnedToday = uniqueCards.count
            
            // Синхронизируем прогресс вызова типа .words
            updateChallengeProgress(type: .words, progress: uniqueCards.count)
            
        } catch {
            print("Ошибка при выборке дневной статистики из SwiftData: \(error)")
        }
    }
    
    private func updateChallengeProgress(type: ChallengeType, progress: Int) {
        guard let index = challenges.firstIndex(where: { $0.type == type }) else { return }
        
        var challenge = challenges[index]
        if challenge.currentProgress != progress {
            challenge.currentProgress = progress
            challenges[index] = challenge
            saveChallengesState()
        }
    }
    
    func completeChallenge(_ challenge: DailyChallenge) {
        addXP(challenge.reward)
        
        if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
            challenges.remove(at: index)
            saveChallengesState()
        }
        
        if challenges.isEmpty {
            showAllCompletedMessage = true
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { self.showAllCompletedMessage = false }
            }
        }
    }
    
    private func addXP(_ amount: Int) {
        userXP += amount
        UserDefaults.standard.set(userXP, forKey: StorageKeys.userXP)
    }
    
    // MARK: - Управление ежедневным состоянием
    
    private func loadDailyState() {
        let todayString = getTodayDateString()
        self.lastUpdateDate = UserDefaults.standard.string(forKey: "lastChallengeDate") ?? ""
        
        if lastUpdateDate != todayString {
            generateNewDailyChallenges()
        } else {
            // Загрузка сохраненного прогресса
            if let data = UserDefaults.standard.data(forKey: "currentChallenges"),
               let saved = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
                self.challenges = saved
            } else {
                generateNewDailyChallenges()
            }
        }
    }
    
    private func checkAndResetDailyStateIfNeeded() {
        let todayString = getTodayDateString()
        if lastUpdateDate != todayString {
            generateNewDailyChallenges()
        }
    }
    
    private func generateNewDailyChallenges() {
        self.challenges = [
            DailyChallenge(title: "Утро лингвиста", description: "Изучи 10 слов", target: 10, reward: 50, type: .words),
            DailyChallenge(title: "Грамматика", description: "Пройди 1 урок грамматики", target: 1, reward: 75, type: .grammar),
            DailyChallenge(title: "Идеальная серия", description: "Пройди викторину без ошибок", target: 1, reward: 100, type: .quiz)
        ]
        
        self.lastUpdateDate = getTodayDateString()
        UserDefaults.standard.set(self.lastUpdateDate, forKey: "lastChallengeDate")
        saveChallengesState()
    }
    
    private func saveChallengesState() {
        if let data = try? JSONEncoder().encode(challenges) {
            UserDefaults.standard.set(data, forKey: "currentChallenges")
        }
    }
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // Вспомогательный метод для UI (Оставить только для тестирования/кнопки, если она необходима)
    // В production прогресс должен расти ТОЛЬКО через refreshStats(context:) при возврате с экрана карточек
    func debugIncrementDailyGoal() {
        // Заглушка, чтобы не ломать верстку в HomeView.
        // В реальном приложении кнопка прогресс-бара не должна увеличивать прогресс по тапу.
    }
}
