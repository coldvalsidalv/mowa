import SwiftUI

struct GrammarLessonView: View {
    @StateObject var viewModel = GrammarLessonViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 1. ХЕДЕР
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                // Прогресс бар
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(Color.orange)
                            .frame(width: geo.size.width * viewModel.progress)
                            .animation(.spring(), value: viewModel.progress)
                    }
                }
                .frame(height: 6)
            }
            .padding()
            
            // 2. КОНТЕНТ (Слайды)
            // ОШИБКА ИСЧЕЗНЕТ, ЕСЛИ ViewModel ИСПРАВЛЕНА
            TabView(selection: $viewModel.currentStepIndex) {
                ForEach(0..<viewModel.lesson.steps.count, id: \.self) { index in
                    let step = viewModel.lesson.steps[index]
                    
                    VStack {
                        if step.type == .theory {
                            TheoryCardView(step: step)
                        } else {
                            // Передаем простые типы данных, чтобы избежать ошибок Binding
                            QuizCardView(
                                step: step,
                                selectedAnswer: viewModel.selectedAnswer,
                                isAnswerCorrect: viewModel.isAnswerCorrect,
                                onAnswer: { answer in
                                    if !viewModel.isAnswerCorrect {
                                        viewModel.checkAnswer(answer)
                                    }
                                }
                            )
                        }
                    }
                    .tag(index)
                    // Блокируем свайп
                    .gesture(DragGesture())
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStepIndex)
            
            // 3. НИЖНЯЯ ПАНЕЛЬ
            VStack {
                if shouldShowFeedback {
                    HStack {
                        Image(systemName: viewModel.isAnswerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(viewModel.isAnswerCorrect ? .green : .red)
                        Text(viewModel.isAnswerCorrect ? "Правильно!" : "Неверно, попробуй еще раз")
                            .font(.headline)
                            .foregroundColor(viewModel.isAnswerCorrect ? .green : .red)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Button(action: handleButtonPress) {
                    Text(buttonTitle)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(buttonColor)
                        .cornerRadius(16)
                }
                .disabled(!isButtonActive)
                .opacity(isButtonActive ? 1.0 : 0.6)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Logic Helpers
    var shouldShowFeedback: Bool {
        return viewModel.currentStep.type == .quiz && viewModel.showQuizFeedback
    }
    
    var buttonTitle: String {
        if viewModel.isLastStep && viewModel.canProceed { return "Завершить" }
        if viewModel.currentStep.type == .quiz && !viewModel.isAnswerCorrect { return "Проверить" }
        return "Далее"
    }
    
    var buttonColor: Color {
        if viewModel.currentStep.type == .quiz {
            if viewModel.isAnswerCorrect { return .green }
            if viewModel.showQuizFeedback && !viewModel.isAnswerCorrect { return .red }
        }
        return .orange
    }
    
    var isButtonActive: Bool {
        if viewModel.currentStep.type == .quiz {
            if viewModel.isAnswerCorrect { return true }
            return viewModel.selectedAnswer != nil
        }
        return true
    }
    
    func handleButtonPress() {
        if viewModel.isLastStep && viewModel.canProceed {
            dismiss()
        } else {
            viewModel.nextStep()
        }
    }
}

// MARK: - Subviews

struct TheoryCardView: View {
    let step: GrammarStep
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(step.title)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.primary)
                Divider()
                Text(LocalizedStringKey(step.content))
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .padding(.bottom, 20)
                Spacer()
            }
            .padding(24)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
            .padding()
        }
    }
}

struct QuizCardView: View {
    let step: GrammarStep
    let selectedAnswer: String?
    let isAnswerCorrect: Bool
    let onAnswer: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(step.title)
                .font(.headline)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            Text(step.question ?? "")
                .font(.title)
                .bold()
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            VStack(spacing: 12) {
                ForEach(step.answers ?? [], id: \.self) { answer in
                    Button(action: {
                        onAnswer(answer)
                    }) {
                        HStack {
                            Text(answer)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            
                            if selectedAnswer == answer {
                                Image(systemName: isAnswerCorrect ? "checkmark.circle.fill" : "circle.circle.fill")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(getBackgroundColor(for: answer))
                        .foregroundColor(getTextColor(for: answer))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(getBorderColor(for: answer), lineWidth: 2)
                        )
                    }
                }
            }
            Spacer()
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
        .padding()
    }
    
    // Helpers for Colors
    func getBackgroundColor(for answer: String) -> Color {
        if selectedAnswer == answer {
            if isAnswerCorrect { return Color.green.opacity(0.2) }
            return Color.red.opacity(0.1)
        }
        return Color(UIColor.systemBackground)
    }
    
    func getBorderColor(for answer: String) -> Color {
        if selectedAnswer == answer {
            if isAnswerCorrect { return .green }
            return .red
        }
        return Color.gray.opacity(0.2)
    }
    
    func getTextColor(for answer: String) -> Color {
        if selectedAnswer == answer {
            if isAnswerCorrect { return .green }
            return .red
        }
        return .primary
    }
}
