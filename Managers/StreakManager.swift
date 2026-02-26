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
        // Установка дефолтных значений при первом запуске
        defaults.register(defaults: [
            StorageKeys.dayStreak: 0,
            StorageKeys.streakFreezes: 2,
            StorageKeys.lastPracticeDate: 0.0
        ])
        
        self.dayStreak = defaults.integer(forKey: StorageKeys.dayStreak)
        self.streakFreezes = defaults.integer(forKey: StorageKeys.streakFreezes)
        
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
                        // Сброс стрика, так как заморозок не хватило
                        dayStreak = 0
                        streakFreezes = 2 // Выдача новых заморозок после сброса (опционально)
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
