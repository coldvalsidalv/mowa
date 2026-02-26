import SwiftUI
import Combine

class FlashcardViewModel: ObservableObject {
    @Published var currentWord: WordItem?
    @Published var isFinished = false
    @Published var progress: CGFloat = 0.0
    
    private var sessionWords: [WordItem] = []
    private var totalSessionCount: Int = 0
    
    private let categories: [String]
    private let isReviewMode: Bool
    
    init(categories: [String], isReviewMode: Bool) {
        self.categories = categories
        self.isReviewMode = isReviewMode
        loadWords()
    }
    
    func loadWords() {
        // Убедитесь, что DataLoader.shared.loadWords() возвращает [WordItem]
        let allWords = DataLoader.shared.loadWords()
        
        if isReviewMode {
            let currentTime = Int(Date().timeIntervalSince1970)
            sessionWords = allWords.filter { word in
                return word.safeNextReview != 0 && word.safeNextReview <= currentTime
            }
        } else {
            sessionWords = allWords.filter { word in
                return categories.contains(word.category)
            }
            sessionWords.shuffle()
        }
        
        totalSessionCount = sessionWords.count
        nextWord()
    }
    
    func nextWord() {
        guard !sessionWords.isEmpty else {
            currentWord = nil
            isFinished = true
            progress = 1.0
            return
        }
        
        currentWord = sessionWords.removeFirst()
        
        if totalSessionCount > 0 {
            let completed = totalSessionCount - sessionWords.count - 1
            withAnimation {
                progress = CGFloat(completed) / CGFloat(totalSessionCount)
            }
        }
    }
    
    func processAnswer(isCorrect: Bool) {
        guard var word = currentWord else { return }
        let now = Int(Date().timeIntervalSince1970)
        
        var currentBox = word.safeBox
        
        if isCorrect {
            currentBox += 1
            if currentBox > 5 { currentBox = 5 }
            
            word.safeBox = currentBox
            word.safeLastReview = now
            word.safeNextReview = calculateNextReview(box: currentBox, from: now)
            
            // Засчитываем прогресс в стрик только при правильном ответе
            StreakManager.shared.completeLesson()
        } else {
            // При ошибке возвращаем на 1 уровень и сбрасываем дату повторения
            word.safeBox = 1
            word.safeNextReview = 0
            
            // Возвращаем слово в конец очереди, чтобы повторить его в этой же сессии
            sessionWords.append(word)
            totalSessionCount += 1
        }
        
        saveWordUpdate(word)
        nextWord()
    }
    
    private func saveWordUpdate(_ updatedWord: WordItem) {
        var allWords = DataLoader.shared.loadWords()
        if let index = allWords.firstIndex(where: { $0.id == updatedWord.id }) {
            allWords[index] = updatedWord
            // Используем ContentManager для сохранения (проверьте наличие этого метода)
            ContentManager.shared.saveWords(allWords)
        }
    }
    
    private func calculateNextReview(box: Int, from now: Int) -> Int {
        let day = 86400
        switch box {
        case 1: return now + day
        case 2: return now + (day * 3)
        case 3: return now + (day * 7)
        case 4: return now + (day * 14)
        case 5: return now + (day * 30)
        default: return now
        }
    }
}
