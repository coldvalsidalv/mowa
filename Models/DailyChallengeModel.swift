import Foundation

enum ChallengeType: String, Codable {
    case words, quiz, grammar
}

struct DailyChallenge: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let description: String
    let target: Int
    var currentProgress: Int
    let reward: Int
    let type: ChallengeType
    
    // Динамический расчет времени до конца дня (полночи)
    var timeLeft: String {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return "0ч 0мин" }
        let diff = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
        return "\(diff.hour ?? 0)ч \(diff.minute ?? 0)мин"
    }
    
    var progress: Double { min(Double(currentProgress) / Double(target), 1.0) }
    var isCompleted: Bool { currentProgress >= target }
    
    init(id: UUID = UUID(), title: String, description: String, target: Int, currentProgress: Int = 0, reward: Int, type: ChallengeType) {
        self.id = id
        self.title = title
        self.description = description
        self.target = target
        self.currentProgress = currentProgress
        self.reward = reward
        self.type = type
    }
}
