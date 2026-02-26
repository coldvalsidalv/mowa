import SwiftUI
import Combine
import UIKit // Необходим для Haptic Feedback (UINotificationFeedbackGenerator)

class GrammarLessonViewModel: ObservableObject {
    @Published var lesson: GrammarLesson
    @Published var currentStepIndex: Int = 0
    
    @Published var selectedAnswer: String? = nil
    @Published var isAnswerCorrect: Bool = false
    @Published var showQuizFeedback: Bool = false
    
    var progress: Double {
        guard !lesson.steps.isEmpty else { return 0 }
        return Double(currentStepIndex) / Double(lesson.steps.count)
    }
    
    var currentStep: GrammarStep {
        guard lesson.steps.indices.contains(currentStepIndex) else {
            // Безопасный фоллбэк, чтобы избежать краша (Array out of bounds)
            return GrammarStep(type: .theory, title: "", content: "", question: nil, answers: nil, correctAnswer: nil)
        }
        return lesson.steps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex >= lesson.steps.count - 1
    }
    
    var canProceed: Bool {
        guard lesson.steps.indices.contains(currentStepIndex) else { return false }
        let step = lesson.steps[currentStepIndex]
        switch step.type {
        case .theory: return true
        case .quiz: return isAnswerCorrect
        }
    }
    
    init(lesson: GrammarLesson) {
        self.lesson = lesson
    }
    
    func checkAnswer(_ answer: String) {
        selectedAnswer = answer
        showQuizFeedback = true
        
        let generator = UINotificationFeedbackGenerator()
        if answer == currentStep.correctAnswer {
            isAnswerCorrect = true
            generator.notificationOccurred(.success)
        } else {
            isAnswerCorrect = false
            generator.notificationOccurred(.error)
        }
    }
    
    func nextStep() {
        if currentStepIndex < lesson.steps.count - 1 {
            withAnimation(.easeInOut) {
                currentStepIndex += 1
                selectedAnswer = nil
                isAnswerCorrect = false
                showQuizFeedback = false
            }
        }
    }
    
    func finishLesson() {
        var completed = UserDefaults.standard.stringArray(forKey: StorageKeys.completedGrammarLessons) ?? []
        
        if !completed.contains(lesson.id) {
            completed.append(lesson.id)
            UserDefaults.standard.set(completed, forKey: StorageKeys.completedGrammarLessons)
            
            // Начисление XP за первичное прохождение с использованием StorageKeys
            let currentXP = UserDefaults.standard.integer(forKey: StorageKeys.userXP)
            UserDefaults.standard.set(currentXP + 50, forKey: StorageKeys.userXP)
            
            // Обновление стрика
            StreakManager.shared.completeLesson()
        }
    }
}
