import SwiftUI
import Combine

class QuizViewModel: ObservableObject {
    // Текущий вопрос (слово)
    @Published var currentWord: WordItem?
    
    // Варианты ответов (переводы)
    @Published var options: [String] = []
    
    // Счет и номер вопроса
    @Published var score: Int = 0
    @Published var questionNumber: Int = 1
    
    // Состояния интерфейса
    @Published var showFeedback: Bool = false
    @Published var isCorrect: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var isGameOver: Bool = false
    
    // Все слова
    private var allWords: [WordItem] = []
    
    // Максимальное количество вопросов в раунде
    let maxQuestions = 10
    
    init() {
        loadData()
        startGame()
    }
    
    func loadData() {
        self.allWords = DataLoader.shared.loadWords()
    }
    
    func startGame() {
        score = 0
        questionNumber = 1
        isGameOver = false
        generateQuestion()
    }
    
    func generateQuestion() {
        // Берем случайное слово
        guard let randomWord = allWords.randomElement() else { return }
        currentWord = randomWord
        
        // Генерируем варианты ответов
        var answers: [String] = [randomWord.translation] // Правильный ответ
        
        // Добавляем 3 неправильных (дистракторы)
        let distractors = allWords
            .filter { $0.id != randomWord.id } // Исключаем правильное слово
            .shuffled()
            .prefix(3)
            .map { $0.translation }
        
        answers.append(contentsOf: distractors)
        
        // Перемешиваем варианты
        options = answers.shuffled()
        
        // Сбрасываем состояние фидбека
        showFeedback = false
    }
    
    func checkAnswer(_ selectedAnswer: String) {
        guard let word = currentWord else { return }
        
        showFeedback = true
        
        if selectedAnswer == word.translation {
            // ПРАВИЛЬНО
            score += 10 // +10 XP за правильный ответ
            isCorrect = true
            feedbackMessage = "Отлично!"
            
            // Можно помечать слово как выученное, если ответил верно (опционально)
            // ProgressService.shared.markAsLearned(word.id)
            
        } else {
            // НЕПРАВИЛЬНО
            isCorrect = false
            feedbackMessage = "Правильный ответ: \(word.translation)"
        }
        
        // Задержка перед следующим вопросом
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.nextQuestion()
        }
    }
    
    private func nextQuestion() {
        if questionNumber >= maxQuestions {
            finishGame()
        } else {
            questionNumber += 1
            generateQuestion()
        }
    }
    
    private func finishGame() {
        isGameOver = true
        // Тут можно сохранить общий XP пользователя
    }
    
    // Вспомогательный метод для сброса
    func restart() {
        startGame()
    }
}
