import SwiftUI
import Combine

final class FlashcardViewModel: ObservableObject {
    @Published var currentWord: WordItem?
    @Published var isFinished = false
    @Published var progress: CGFloat = 0.0
    
    private var sessionWords: [WordItem] = []
    private var totalSessionCount: Int = 0
    
    // Единый кеш слов для минимизации обращений к диску
    private var allWordsCache: [WordItem] = []
    
    private let categories: [String]
    private let isReviewMode: Bool
    
    init(categories: [String], isReviewMode: Bool) {
        self.categories = categories
        self.isReviewMode = isReviewMode
        // Используем существующий DataLoader
        self.allWordsCache = DataLoader.shared.loadWords()
        loadWords()
    }
    
    func loadWords() {
        if isReviewMode {
            let currentTime = Int(Date().timeIntervalSince1970)
            sessionWords = allWordsCache.filter { word in
                return word.safeNextReview != 0 && word.safeNextReview <= currentTime
            }
        } else {
            sessionWords = allWordsCache.filter { word in
                return categories.contains(word.category) || categories.isEmpty
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
            let completedCount = totalSessionCount - sessionWords.count - 1
            withAnimation(.easeInOut) {
                progress = CGFloat(completedCount) / CGFloat(totalSessionCount)
            }
        }
    }
    
    func processAnswer(isCorrect: Bool) {
        guard var word = currentWord else { return }
        let now = Int(Date().timeIntervalSince1970)
        
        if isCorrect {
            let currentBox = min(word.safeBox + 1, 5)
            word.safeBox = currentBox
            word.safeLastReview = now
            word.safeNextReview = calculateNextReview(box: currentBox, from: now)
            
            // Обновляем стрик только при успехе
            StreakManager.shared.completeLesson()
        } else {
            // При ошибке сбрасываем в первую коробку
            word.safeBox = 1
            word.safeNextReview = 0
            
            // Возвращаем в конец очереди текущей сессии
            sessionWords.append(word)
            totalSessionCount += 1
        }
        
        updateCacheAndSave(word)
        nextWord()
    }
    
    private func updateCacheAndSave(_ updatedWord: WordItem) {
        // Обновляем в памяти
        if let index = allWordsCache.firstIndex(where: { $0.id == updatedWord.id }) {
            allWordsCache[index] = updatedWord
            // Сохраняем весь массив через существующий ContentManager
            ContentManager.shared.saveWords(allWordsCache)
        }
    }
    
    private func calculateNextReview(box: Int, from now: Int) -> Int {
        let day = 86400
        let intervals = [0, 1, 3, 7, 14, 30]
        let daysToAdd = intervals[min(box, intervals.count - 1)]
        return now + (daysToAdd * day)
    }
}
