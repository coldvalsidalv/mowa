import SwiftUI
import Combine

class StudySessionViewModel: ObservableObject {
    @Published var currentWord: WordItem?
    @Published var isFinished = false
    @Published var progress: CGFloat = 0.0
    
    private var sessionWords: [WordItem] = []
    private var totalSessionCount: Int = 0
    
    // Параметры
    private let categories: [String]
    private let isReviewMode: Bool
    
    // --- ИСПРАВЛЕНИЕ: Добавляем пустой init для HomeView ---
    init() {
        self.categories = []
        self.isReviewMode = false
        // Для HomeView загрузка слов не обязательна сразу,
        // либо можно загрузить все для статистики
    }
    
    // Основной init для обучения
    init(categories: [String], isReviewMode: Bool) {
        self.categories = categories
        self.isReviewMode = isReviewMode
        loadWords()
    }
    
    func loadWords() {
        let allWords = DataLoader.shared.loadWords()
        
        if isReviewMode {
            // РЕЖИМ ПОВТОРЕНИЯ (SRS)
            let currentTime = Int(Date().timeIntervalSince1970)
            
            // Фильтруем слова, у которых nextReview <= сейчас
            sessionWords = allWords.filter { word in
                let nextReview = word.nextReview ?? 0
                return nextReview != 0 && nextReview <= currentTime
            }
            
        } else {
            // РЕЖИМ ИЗУЧЕНИЯ
            if categories.isEmpty {
                 sessionWords = [] // Если категорий нет (пустой инит), список пуст
            } else {
                sessionWords = allWords.filter { word in
                    return categories.contains(word.category)
                }
                sessionWords.shuffle()
            }
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
    
    func handleAnswer(isCorrect: Bool) {
        guard var word = currentWord else { return }
        
        let now = Int(Date().timeIntervalSince1970)
        var currentBox = word.box ?? 0
        
        if isCorrect {
            currentBox += 1
            if currentBox > 5 { currentBox = 5 }
            
            word.box = currentBox
            word.lastReview = now
            word.nextReview = calculateNextReview(box: currentBox, from: now)
            
        } else {
            word.box = 1
            word.nextReview = 0
            sessionWords.append(word)
            totalSessionCount += 1
        }
        
        saveWordUpdate(word)
        nextWord()
    }
    
    // Метод для статистики грамматики (нужен для HomeView)
    func getGrammarStats() -> (learned: Int, total: Int) {
        let lessons = DataLoader.shared.loadGrammar()
        // Пока возвращаем заглушку по прогрессу, так как у нас нет сохранения прогресса грамматики
        // В будущем можно добавить поле isCompleted в GrammarLesson и сохранять его
        return (learned: 0, total: lessons.count)
    }
    
    private func saveWordUpdate(_ updatedWord: WordItem) {
        var allWords = DataLoader.shared.loadWords()
        if let index = allWords.firstIndex(where: { $0.id == updatedWord.id }) {
            allWords[index] = updatedWord
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
