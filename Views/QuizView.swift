import SwiftUI

struct QuizView: View {
    @StateObject var viewModel = QuizViewModel()
    @Environment(\.dismiss) var dismiss // Чтобы можно было выйти
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.isGameOver {
                // ЭКРАН РЕЗУЛЬТАТОВ
                VStack(spacing: 24) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                    
                    Text("Викторина завершена!")
                        .font(.title)
                        .bold()
                    
                    Text("Твой результат: \(viewModel.score) XP")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Button(action: {
                        viewModel.restart()
                    }) {
                        Text("Сыграть еще раз")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
            } else {
                // ЭКРАН ВОПРОСА
                VStack {
                    // Хедер
                    HStack {
                        Text("Вопрос \(viewModel.questionNumber)/\(viewModel.maxQuestions)")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.score) XP")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.orange)
                    }
                    .padding()
                    
                    Spacer()
                    
                    if let word = viewModel.currentWord {
                        // Карточка с вопросом
                        VStack(spacing: 20) {
                            Text("Как переводится?")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundColor(.gray)
                            
                            Text(word.polish)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Варианты ответов
                        VStack(spacing: 12) {
                            ForEach(viewModel.options, id: \.self) { option in
                                Button(action: {
                                    viewModel.checkAnswer(option)
                                }) {
                                    Text(option)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 60)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 2)
                                        // Если показан ответ, подсвечиваем правильный/неправильный
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(getBorderColor(for: option), lineWidth: 3)
                                        )
                                }
                                .disabled(viewModel.showFeedback) // Блокируем нажатия после ответа
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Всплывающее уведомление о результате (Feedback)
            if viewModel.showFeedback {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: viewModel.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.isCorrect ? .green : .red)
                        
                        Text(viewModel.feedbackMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isCorrect ? Color.green : Color.red)
                    .cornerRadius(16)
                    .padding()
                    .shadow(radius: 10)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationTitle("Викторина")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Логика цвета рамок
    func getBorderColor(for option: String) -> Color {
        guard viewModel.showFeedback else { return .clear }
        
        if option == viewModel.currentWord?.translation {
            return .green // Правильный ответ всегда зеленый
        }
        
        // Если это ответ, который выбрал юзер (но мы тут не храним выбранный явно во View,
        // упростим: подсвечиваем только правильный. Если хочешь подсветить ошибку красным,
        // нужно добавить selectedAnswer во ViewModel)
        return .clear
    }
}
