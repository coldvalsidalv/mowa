import SwiftUI

struct GrammarLessonView: View {
    @StateObject var viewModel: GrammarLessonViewModel
    @Environment(\.dismiss) var dismiss
    
    init(lesson: GrammarLesson) {
        _viewModel = StateObject(wrappedValue: GrammarLessonViewModel(lesson: lesson))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. ХЕДЕР
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(Color.orange)
                            // Явное приведение типов (Double -> CGFloat) устраняет ошибку компиляции
                            .frame(width: geo.size.width * CGFloat(viewModel.progress))
                            .animation(.spring(), value: viewModel.progress)
                    }
                }
                .frame(height: 6)
            }
            .padding()
            
            // 2. КОНТЕНТ (Слайды)
            TabView(selection: $viewModel.currentStepIndex) {
                // Использование enumerated() избавляет от ошибки ViewBuilder внутри ForEach
                ForEach(Array(viewModel.lesson.steps.enumerated()), id: \.offset) { index, step in
                    VStack {
                        if step.type == .theory {
                            TheoryCardView(step: step)
                        } else {
                            QuizCardView(
                                step: step,
                                selectedAnswer: viewModel.selectedAnswer,
                                isAnswerCorrect: viewModel.isAnswerCorrect,
                                showFeedback: viewModel.showQuizFeedback,
                                onAnswer: { answer in
                                    if !viewModel.isAnswerCorrect {
                                        viewModel.checkAnswer(answer)
                                    }
                                }
                            )
                        }
                    }
                    .tag(index)
                    // Блокируем свайп, заставляя пользователя нажимать кнопки
                    .contentShape(Rectangle())
                    .gesture(DragGesture())
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStepIndex)
            
            // 3. НИЖНЯЯ ПАНЕЛЬ
            VStack {
                if viewModel.currentStep.type == .quiz && viewModel.showQuizFeedback {
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
                
                Button(action: {
                    if viewModel.isLastStep && viewModel.canProceed {
                        viewModel.finishLesson()
                        dismiss()
                    } else {
                        viewModel.nextStep()
                    }
                }) {
                    Text(viewModel.isLastStep ? "Завершить" : "Далее")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(viewModel.canProceed ? Color.blue : Color.gray.opacity(0.5))
                        .cornerRadius(16)
                }
                .disabled(!viewModel.canProceed)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
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
    let showFeedback: Bool
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
                    Button(action: { onAnswer(answer) }) {
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
                    .buttonStyle(PlainButtonStyle())
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
    
    // Helpers
    func getBackgroundColor(for answer: String) -> Color {
        if selectedAnswer == answer {
            return isAnswerCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.1)
        }
        return Color(UIColor.systemBackground)
    }
    
    func getBorderColor(for answer: String) -> Color {
        if selectedAnswer == answer {
            return isAnswerCorrect ? .green : .red
        }
        return Color.gray.opacity(0.2)
    }
    
    func getTextColor(for answer: String) -> Color {
        if selectedAnswer == answer {
            return isAnswerCorrect ? .green : .red
        }
        return .primary
    }
}
