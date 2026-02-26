import SwiftUI
import Combine

final class GrammarLessonViewModel: ObservableObject {
    let lesson: GrammarLesson
    
    @Published var currentStepIndex = 0
    @Published var selectedAnswer: String?
    @Published var isAnswerCorrect = false
    @Published var showQuizFeedback = false
    
    // Новые свойства для финального теста
    @Published var showResults = false
    @Published var correctAnswersCount = 0
    private var hasAttemptedCurrentQuestion = false
    
    init(lesson: GrammarLesson) {
        self.lesson = lesson
    }
    
    var currentStep: GrammarStep { lesson.steps[currentStepIndex] }
    var isLastStep: Bool { currentStepIndex == lesson.steps.count - 1 }
    var totalQuizSteps: Int { lesson.steps.filter { $0.type == .quiz }.count }
    
    var canProceed: Bool {
        if currentStep.type == .theory { return true }
        return showQuizFeedback && isAnswerCorrect
    }
    
    var progress: Double {
        guard !lesson.steps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(lesson.steps.count)
    }
    
    func checkAnswer(_ answer: String) {
        selectedAnswer = answer
        // Предполагается, что в GrammarStep есть свойство correctAnswer.
        // Если у вас оно называется иначе, замените на актуальное.
        isAnswerCorrect = (answer == currentStep.correctAnswer)
        showQuizFeedback = true
        
        // Засчитываем балл только если пользователь ответил верно с первой попытки
        if isAnswerCorrect && !hasAttemptedCurrentQuestion {
            correctAnswersCount += 1
        }
        hasAttemptedCurrentQuestion = true
    }
    
    func nextStep() {
        if isLastStep {
            withAnimation { showResults = true }
        } else {
            withAnimation(.easeInOut) {
                currentStepIndex += 1
                selectedAnswer = nil
                isAnswerCorrect = false
                showQuizFeedback = false
                hasAttemptedCurrentQuestion = false
            }
        }
    }
    
    func finishLesson() {
        var completed = UserDefaults.standard.stringArray(forKey: StorageKeys.completedGrammarLessons) ?? []
        
        if !completed.contains(lesson.id) {
            completed.append(lesson.id)
            UserDefaults.standard.set(completed, forKey: StorageKeys.completedGrammarLessons)
            
            let currentXP = UserDefaults.standard.integer(forKey: StorageKeys.userXP)
            // Базовые 50 XP + по 5 XP за каждый правильный ответ в тесте
            let earnedXP = 50 + (correctAnswersCount * 5)
            UserDefaults.standard.set(currentXP + earnedXP, forKey: StorageKeys.userXP)
            
            StreakManager.shared.completeLesson()
        }
    }
}
