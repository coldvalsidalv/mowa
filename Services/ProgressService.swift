import Foundation

class ProgressService {
    static let shared = ProgressService()
    
    private let learnedKey = "learnedWordsIDs"
    
    // Получить список ID выученных слов (Теперь возвращает Set<Int>)
    func getLearnedIDs() -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: learnedKey) as? [Int] ?? []
        return Set(array)
    }
    
    // Пометить слово как выученное (Принимает Int)
    func markAsLearned(_ id: Int) {
        var currentIDs = getLearnedIDs()
        currentIDs.insert(id)
        
        UserDefaults.standard.set(Array(currentIDs), forKey: learnedKey)
    }
    
    // Сброс прогресса (для настроек)
    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: learnedKey)
    }
}
