import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = QuizViewModel()
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            if viewModel.isFinished {
                quizResultView
            } else if let currentQuestion = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    quizHeader
                    Spacer()
                    questionCard(for: currentQuestion)
                    Spacer()
                    answerOptions(for: currentQuestion)
                    Spacer()
                    actionButton
                }
                .padding()
            } else {
                loadingView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Передача контекста обязательна для выборки слов из БД
            viewModel.startSession(context: modelContext)
        }
    }
    
    // MARK: - UI Components
    
    private var quizHeader: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(viewModel.progress))
                        .animation(.spring(), value: viewModel.progress)
                }
            }
            .frame(height: 8)
            
            Text("\(viewModel.currentIndex + 1)/\(viewModel.totalQuestions)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.gray)
        }
    }
    
    private func questionCard(for question: QuizQuestion) -> some View {
        VStack(spacing: 16) {
            Text("Как переводится?")
                .font(.subheadline)
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .kerning(1.2)
            
            Text(question.word.polish) // Изменено с word.word на word.polish
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func answerOptions(for question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options, id: \.self) { option in
                Button(action: { viewModel.submitAnswer(option) }) {
                    HStack {
                        Text(option)
                            .font(.headline)
                        Spacer()
                        if viewModel.selectedAnswer == option {
                            Image(systemName: viewModel.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        } else if viewModel.showFeedback && option == question.word.translation {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(buttonBackground(for: option, in: question))
                    .foregroundColor(buttonForegroundColor(for: option, in: question))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(buttonBorderColor(for: option, in: question), lineWidth: 2)
                    )
                }
                .disabled(viewModel.showFeedback)
            }
        }
    }
    
    private var actionButton: some View {
        Button(action: { viewModel.nextQuestion() }) {
            Text(viewModel.isLastQuestion ? "Завершить" : "Далее")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(viewModel.showFeedback ? Color.orange : Color.gray.opacity(0.3))
                .cornerRadius(28)
        }
        .disabled(!viewModel.showFeedback)
        .padding(.bottom, 10)
    }
    
    private var quizResultView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.1)).frame(width: 150, height: 150)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text("Викторина пройдена!")
                    .font(.title.bold())
                Text("Ваш результат: \(viewModel.score) из \(viewModel.totalQuestions)")
                    .foregroundColor(.gray)
            }
            
            Button(action: { dismiss() }) {
                Text("Вернуться")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.orange)
                    .cornerRadius(28)
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Подготовка вопросов...")
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Button Styling Helpers
    
    private func buttonBackground(for option: String, in question: QuizQuestion) -> Color {
        guard viewModel.showFeedback else { return Color(UIColor.secondarySystemGroupedBackground) }
        if option == question.word.translation { return Color.green.opacity(0.1) }
        if option == viewModel.selectedAnswer && !viewModel.isCorrect { return Color.red.opacity(0.1) }
        return Color(UIColor.secondarySystemGroupedBackground)
    }
    
    private func buttonForegroundColor(for option: String, in question: QuizQuestion) -> Color {
        guard viewModel.showFeedback else { return .primary }
        if option == question.word.translation { return .green }
        if option == viewModel.selectedAnswer && !viewModel.isCorrect { return .red }
        return .primary.opacity(0.5)
    }
    
    private func buttonBorderColor(for option: String, in question: QuizQuestion) -> Color {
        guard viewModel.showFeedback else { return .clear }
        if option == question.word.translation { return .green }
        if option == viewModel.selectedAnswer && !viewModel.isCorrect { return .red }
        return .clear
    }
}
