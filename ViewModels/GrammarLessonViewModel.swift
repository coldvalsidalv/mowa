import SwiftUI
import SwiftData
import Combine

final class GrammarLessonViewModel: ObservableObject {
    let lesson: GrammarLesson
    private var context: ModelContext?
    private let scheduler: FSRSScheduler

    @Published var currentStepIndex = 0
    @Published var selectedAnswer: String?
    @Published var isAnswerCorrect = false
    @Published var showQuizFeedback = false
    @Published var showResults = false
    @Published var correctAnswersCount = 0
    private var hasAttemptedCurrentQuestion = false

    init(lesson: GrammarLesson) {
        self.lesson = lesson
        let p = FSRSParamStore.shared.current
        self.scheduler = FSRSScheduler(
            parameters: p.parameters,
            desiredRetention: p.desiredRetention,
            learningSteps: p.learningSteps,
            relearningSteps: p.relearningSteps
        )
    }

    /// Called from GrammarLessonView.onAppear — passes the SwiftData context
    func configure(context: ModelContext) {
        self.context = context
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
        isAnswerCorrect = (answer == currentStep.correctAnswer)
        showQuizFeedback = true
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
        guard let context else {
            print("❌ GrammarLessonViewModel: context not configured")
            return
        }

        // FSRS rating based on the quiz result (for theory lessons — good by default)
        let score = totalQuizSteps > 0 ? Double(correctAnswersCount) / Double(totalQuizSteps) : 1.0
        let rating = FSRSRating.from(score: score)

        // Find or create the progress record
        let lessonId = lesson.id
        let descriptor = FetchDescriptor<GrammarProgress>(
            predicate: #Predicate { $0.lessonId == lessonId }
        )
        let grammarProgress: GrammarProgress
        if let existing = (try? context.fetch(descriptor))?.first {
            grammarProgress = existing
        } else {
            grammarProgress = GrammarProgress(lessonId: lesson.id, lessonTitle: lesson.title, lessonLevel: lesson.level)
            context.insert(grammarProgress)
        }

        // Apply FSRS
        let updated = scheduler.schedule(card: grammarProgress.fsrsData.snapshot(), rating: rating, now: Date())
        grammarProgress.fsrsData.apply(updated)
        grammarProgress.lastScore = score

        // Mark the lesson completed — read by LessonsViewModel (level progress)
        // and ProfileViewModel (achievements).
        var completed = UserDefaults.standard.stringArray(forKey: StorageKeys.completedGrammarLessons) ?? []
        if !completed.contains(lesson.id) {
            completed.append(lesson.id)
            UserDefaults.standard.set(completed, forKey: StorageKeys.completedGrammarLessons)
        }

        // XP
        let currentXP = UserDefaults.standard.integer(forKey: StorageKeys.userXP)
        UserDefaults.standard.set(currentXP + 50 + (correctAnswersCount * 5), forKey: StorageKeys.userXP)

        StreakManager.shared.completeLesson()

        do {
            try context.save()
        } catch {
            print("❌ GrammarLessonViewModel: failed to save — \(error)")
        }

        if UserDefaults.standard.bool(forKey: StorageKeys.notificationsEnabled) {
            NotificationManager.shared.scheduleGrammarReview()
        }

        NotificationCenter.default.post(name: .grammarLessonCompleted, object: nil)
    }
}

extension Notification.Name {
    static let grammarLessonCompleted = Notification.Name("grammarLessonCompleted")
}
