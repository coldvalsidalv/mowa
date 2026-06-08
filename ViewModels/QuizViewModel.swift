import SwiftUI
import SwiftData
import Combine

/// Модель вопроса викторины. Использует актуальную сущность VocabItem.
struct QuizQuestion {
    let word: VocabItem
    let options: [String]
}

@MainActor
final class QuizViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var currentIndex: Int = 0
    @Published var selectedAnswer: String?
    @Published var showFeedback: Bool = false
    @Published var isCorrect: Bool = false
    @Published var score: Int = 0
    @Published var isFinished: Bool = false
    
    var totalQuestions: Int { questions.count }
    
    var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }
    
    var isLastQuestion: Bool {
        currentIndex == questions.count - 1
    }
    
    /// Инициализация сессии: выборка слов из SwiftData и генерация дистракторов.
    /// Требует передачи контекста для доступа к локальной БД.
    func startSession(context: ModelContext) {
        let totalCount = (try? context.fetchCount(FetchDescriptor<VocabItem>())) ?? 0
        guard totalCount >= 4 else {
            print("❌ Недостаточно слов в базе для запуска викторины (минимум 4)")
            return
        }

        var descriptor = FetchDescriptor<VocabItem>()
        let poolSize = min(50, totalCount)
        descriptor.fetchOffset = totalCount > poolSize ? Int.random(in: 0...(totalCount - poolSize)) : 0
        descriptor.fetchLimit = poolSize
        let pool = (try? context.fetch(descriptor)) ?? []

        guard pool.count >= 4 else { return }

        let questionWords = Array(pool.shuffled().prefix(10))
        self.questions = questionWords.map { word in
            var options = [word.translation]

            let distractors = pool.filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.translation }
            options.append(contentsOf: distractors)

            return QuizQuestion(word: word, options: options.shuffled())
        }
        
        self.score = 0
        self.currentIndex = 0
        self.isFinished = false
        self.showFeedback = false
        self.selectedAnswer = nil
    }
    
    func submitAnswer(_ answer: String) {
        guard let current = currentQuestion else { return }
        selectedAnswer = answer
        isCorrect = (answer == current.word.translation)
        if isCorrect { score += 1 }
        showFeedback = true
    }
    
    func nextQuestion() {
        if isLastQuestion {
            finishSession()
        } else {
            withAnimation {
                currentIndex += 1
                selectedAnswer = nil
                showFeedback = false
            }
        }
    }
    
    private func finishSession() {
        isFinished = true

        let defaults = UserDefaults.standard
        let currentXP = defaults.integer(forKey: StorageKeys.userXP)
        defaults.set(currentXP + (score * 5), forKey: StorageKeys.userXP)

        StreakManager.shared.completeLesson()

        // Сообщаем HomeViewModel что квиз завершён
        let isPerfect = score == totalQuestions
        NotificationCenter.default.post(
            name: .quizCompleted,
            object: nil,
            userInfo: ["isPerfect": isPerfect]
        )
    }
}

extension Notification.Name {
    static let quizCompleted = Notification.Name("quizCompleted")
}
