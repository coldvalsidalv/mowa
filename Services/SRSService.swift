import Foundation

class SRSService {
    static let shared = SRSService()
    
    private init() {}
    
    // Основная функция расчета
    func calculateReview(for word: WordItem, isCorrect: Bool) -> WordItem {
        var updatedWord = word
        
        // Получаем текущее время в секундах (Int)
        let now = Int(Date().timeIntervalSince1970)
        
        // Безопасно достаем текущий уровень (если nil, то 0)
        var currentBox = updatedWord.box ?? 0
        
        if isCorrect {
            // Если ответил правильно -> повышаем уровень (Box)
            currentBox += 1
            if currentBox > 5 { currentBox = 5 } // Максимум 5
            
            updatedWord.box = currentBox
            updatedWord.lastReview = now
            updatedWord.nextReview = now + getInterval(for: currentBox)
            
        } else {
            // Если ошибся -> сброс на 1 уровень
            updatedWord.box = 1
            updatedWord.lastReview = now
            updatedWord.nextReview = 0 // Повторить немедленно
        }
        
        return updatedWord
    }
    
    // Вспомогательная функция интервалов (в секундах)
    private func getInterval(for box: Int) -> Int {
        let day = 86400
        
        switch box {
        case 1: return day            // 1 день
        case 2: return day * 3        // 3 дня
        case 3: return day * 7        // 1 неделя
        case 4: return day * 14       // 2 недели
        case 5: return day * 30       // 1 месяц
        default: return day
        }
    }
}
