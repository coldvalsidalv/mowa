import SwiftUI
import Combine

// В перспективе: вынести в Models/DailyChallenge.swift
enum ChallengeType {
    case words, quiz, grammar
}

// В перспективе: вынести в Models/DailyChallenge.swift
struct DailyChallenge: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let target: Int
    var currentProgress: Int
    let reward: Int
    let timeLeft: String
    let type: ChallengeType
    
    var progress: Double { min(Double(currentProgress) / Double(target), 1.0) }
    var isCompleted: Bool { currentProgress >= target }
}

final class HomeViewModel: ObservableObject {
    @Published var userXP: Int {
        didSet { UserDefaults.standard.set(userXP, forKey: StorageKeys.userXP) }
    }
    
    @Published var wordsLearnedToday: Int = 8
    @Published var dailyWordGoal: Int = 10
    
    @Published var challenges: [DailyChallenge] = [
        DailyChallenge(title: "Утро лингвиста", description: "Выучи 5 новых слов", target: 5, currentProgress: 3, reward: 50, timeLeft: "2ч 15мин", type: .words),
        DailyChallenge(title: "Грамматика", description: "Пройди 1 урок грамматики", target: 1, currentProgress: 0, reward: 75, timeLeft: "5ч 00мин", type: .grammar),
        DailyChallenge(title: "Идеальная серия", description: "Пройди викторину без ошибок", target: 1, currentProgress: 0, reward: 100, timeLeft: "12ч 45мин", type: .quiz)
    ]
    
    @Published var showAllCompletedMessage = false
    
    var currentLeague: UserLeague {
        UserLeague.determineLeague(for: userXP)
    }
    
    var dailyGoalProgress: Double {
        min(Double(wordsLearnedToday) / Double(dailyWordGoal), 1.0)
    }
    
    var isDailyGoalCompleted: Bool {
        wordsLearnedToday >= dailyWordGoal
    }
    
    init() {
        self.userXP = UserDefaults.standard.integer(forKey: StorageKeys.userXP)
    }
    
    func completeChallenge(_ challenge: DailyChallenge) {
        userXP += challenge.reward
        
        if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
            challenges.remove(at: index)
        }
        
        if challenges.isEmpty {
            showAllCompletedMessage = true
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { self.showAllCompletedMessage = false }
            }
        }
    }
    
    func debugIncrementDailyGoal() {
        guard wordsLearnedToday < dailyWordGoal else { return }
        wordsLearnedToday += 1
        
        if isDailyGoalCompleted {
            userXP += 50
        }
    }
}
