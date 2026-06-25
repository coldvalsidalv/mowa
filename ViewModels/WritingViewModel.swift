import SwiftUI
import SwiftData
import Combine

@MainActor
final class WritingViewModel: ObservableObject {
    enum Phase: Equatable {
        case editing
        case submitting
        case done(WritingFeedback)
        case failed(String)

        static func == (l: Phase, r: Phase) -> Bool {
            switch (l, r) {
            case (.editing, .editing), (.submitting, .submitting): return true
            case (.done, .done), (.failed, .failed): return true
            default: return false
            }
        }
    }

    @Published var text: String = ""
    @Published var phase: Phase = .editing

    let task: WritingTask
    private let context: ModelContext

    init(task: WritingTask, context: ModelContext) {
        self.task = task
        self.context = context
    }

    var wordCount: Int {
        text.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
    }

    var isWithinRange: Bool {
        wordCount >= task.minWords && wordCount <= task.maxWords
    }

    var canSubmit: Bool {
        wordCount >= 10 && phase != .submitting
    }

    func submit() async {
        guard canSubmit else { return }
        phase = .submitting
        do {
            let lang = LanguageManager.shared.currentLanguage
            let feedback = try await APIClient.shared.gradeWriting(task: task, text: text, lang: lang)
            persist(feedback)
            phase = .done(feedback)
        } catch {
            phase = .failed(humanMessage(for: error))
        }
    }

    private func persist(_ feedback: WritingFeedback) {
        let json = (try? JSONEncoder().encode(feedback))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let attempt = WritingAttempt(taskId: task.taskId, userText: text, feedback: feedback, feedbackJSON: json)
        context.insert(attempt)
        try? context.save()
    }

    private func humanMessage(for error: Error) -> String {
        if case let APIError.serverError(code, message) = error {
            if code == 401 { return "Нужно войти в аккаунт, чтобы проверять письма." }
            return message ?? "Сервер недоступен (\(code))."
        }
        return "Не удалось проверить. Проверь соединение и попробуй ещё раз."
    }
}
