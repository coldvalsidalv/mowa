import SwiftUI
import Combine

class GrammarLessonViewModel: ObservableObject {
    // ВАЖНО: @Published обязательно, чтобы работало $viewModel.currentStepIndex
    @Published var lesson: GrammarLesson
    @Published var currentStepIndex: Int = 0
    
    // Состояние квиза
    @Published var selectedAnswer: String? = nil
    @Published var isAnswerCorrect: Bool = false
    @Published var showQuizFeedback: Bool = false
    
    // Прогресс
    var progress: Double {
        guard !lesson.steps.isEmpty else { return 0 }
        return Double(currentStepIndex) / Double(lesson.steps.count)
    }
    
    var currentStep: GrammarStep {
        lesson.steps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex == lesson.steps.count - 1
    }
    
    var canProceed: Bool {
        switch currentStep.type {
        case .theory:
            return true
        case .quiz:
            return isAnswerCorrect
        }
    }
    
    init() {
        // MOCK DATA
        self.lesson = GrammarLesson(
            id: "lesson1",
            title: "Глагол Być (Быть)",
            description: "Основа польского языка",
            level: "A0",
            steps: [
                GrammarStep(
                    type: .theory,
                    title: "Введение",
                    content: "В польском языке глагол **być** (быть) используется постоянно. В отличие от русского, его нельзя опускать.\n\nНельзя сказать 'Я студент'.\nНужно сказать 'Я **ЕСТЬ** студент'.",
                    question: nil, answers: nil, correctAnswer: nil
                ),
                GrammarStep(
                    type: .theory,
                    title: "Спряжение (Ед.ч.)",
                    content: "Запомни формы для единственного числа:\n\n🧑 Ja **jestem** (Я есть)\n🫵 Ty **jesteś** (Ты есть)\n👨 On **jest** (Он есть)",
                    question: nil, answers: nil, correctAnswer: nil
                ),
                GrammarStep(
                    type: .quiz,
                    title: "Проверка",
                    content: "",
                    question: "Как сказать 'Я студент'?",
                    answers: ["Ja student", "Ja jestem studentem", "Ja jesteś studentem"],
                    correctAnswer: "Ja jestem studentem"
                ),
                GrammarStep(
                    type: .quiz,
                    title: "Проверка",
                    content: "",
                    question: "On _____ w domu (дома).",
                    answers: ["jestem", "jesteś", "jest"],
                    correctAnswer: "jest"
                )
            ]
        )
    }
    
    func checkAnswer(_ answer: String) {
        selectedAnswer = answer
        showQuizFeedback = true
        
        if answer == currentStep.correctAnswer {
            isAnswerCorrect = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            isAnswerCorrect = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func nextStep() {
        if currentStepIndex < lesson.steps.count - 1 {
            withAnimation {
                currentStepIndex += 1
                selectedAnswer = nil
                isAnswerCorrect = false
                showQuizFeedback = false
            }
        }
    }
}
