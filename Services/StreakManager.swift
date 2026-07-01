import Foundation
import Combine

final class StreakManager: ObservableObject {
    static let shared = StreakManager()
    private let defaults = UserDefaults.standard
    
    @Published var dayStreak: Int = 0 {
        didSet { defaults.set(dayStreak, forKey: StorageKeys.dayStreak) }
    }
    
    @Published var streakFreezes: Int = 2 {
        didSet { defaults.set(streakFreezes, forKey: StorageKeys.streakFreezes) }
    }
    
    @Published var hasPracticedToday: Bool = false
    
    private init() {
        // Set default values on first launch
        defaults.register(defaults: [
            StorageKeys.dayStreak: 0,
            StorageKeys.streakFreezes: 2,
            StorageKeys.lastPracticeDate: 0.0
        ])
        
        self.dayStreak = defaults.integer(forKey: StorageKeys.dayStreak)
        self.streakFreezes = defaults.integer(forKey: StorageKeys.streakFreezes)
        
        processCalendarLogic()
    }

    /// Recompute the day rollover. iOS keeps the app in memory for days, so
    /// init logic isn't enough — this is also called on scenePhase == .active.
    func refreshDayRollover() {
        processCalendarLogic()
    }

    private func processCalendarLogic() {
        let lastPracticeTime = defaults.double(forKey: StorageKeys.lastPracticeDate)
        
        guard lastPracticeTime > 0 else {
            hasPracticedToday = false
            return
        }
        
        let lastPracticeDate = Date(timeIntervalSince1970: lastPracticeTime)
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastPracticeDate) {
            hasPracticedToday = true
        } else {
            hasPracticedToday = false
            
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfLastPractice = calendar.startOfDay(for: lastPracticeDate)
            
            if let daysPassed = calendar.dateComponents([.day], from: startOfLastPractice, to: startOfToday).day, daysPassed > 0 {
                let missedDays = daysPassed - 1
                
                if missedDays > 0 {
                    if streakFreezes >= missedDays {
                        streakFreezes -= missedDays
                    } else {
                        // Reset the streak, since there weren't enough freezes
                        dayStreak = 0
                        streakFreezes = 2 // Grant new freezes after a reset (optional)
                    }
                }
            }
        }
    }
    
    func completeLesson() {
        guard !hasPracticedToday else { return }
        
        hasPracticedToday = true
        dayStreak += 1
        defaults.set(Date().timeIntervalSince1970, forKey: StorageKeys.lastPracticeDate)
    }
}
