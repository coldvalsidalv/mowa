import Foundation

enum ChallengeType: String, Codable {
    case words, quiz, grammar
}

struct DailyChallenge: Identifiable, Equatable, Codable {
    let id: UUID
    let target: Int
    var currentProgress: Int
    let reward: Int
    let type: ChallengeType

    // Derived from `type` and localized on access, so they follow a runtime
    // language switch. Not stored/Codable — persistence keeps only the type.
    var title: String {
        switch type {
        case .words:   return L("challenge.morning_title")
        case .grammar: return L("challenge.grammar_title")
        case .quiz:    return L("challenge.streak_title")
        }
    }

    var description: String {
        switch type {
        case .words:   return L("challenge.morning_desc")
        case .grammar: return L("challenge.grammar_desc")
        case .quiz:    return L("challenge.streak_desc")
        }
    }

    // Динамический расчет времени до конца дня (полночи)
    var timeLeft: String {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return L("challenge.time_left_fmt", 0, 0) }
        let diff = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
        return L("challenge.time_left_fmt", diff.hour ?? 0, diff.minute ?? 0)
    }
    
    var progress: Double { min(Double(currentProgress) / Double(target), 1.0) }
    var isCompleted: Bool { currentProgress >= target }
    
    init(id: UUID = UUID(), target: Int, currentProgress: Int = 0, reward: Int, type: ChallengeType) {
        self.id = id
        self.target = target
        self.currentProgress = currentProgress
        self.reward = reward
        self.type = type
    }
}
