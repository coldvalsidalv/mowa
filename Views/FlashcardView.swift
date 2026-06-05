import SwiftUI
import SwiftData

struct FlashcardView: View {
    let categories: [String]
    let isReviewMode: Bool
    
    @StateObject private var viewModel: FlashcardViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showExitAlert = false
    
    init(categories: [String], isReviewMode: Bool, context: ModelContext) {
        self.categories = categories
        self.isReviewMode = isReviewMode
        _viewModel = StateObject(wrappedValue: FlashcardViewModel(
            categories: categories,
            isReviewMode: isReviewMode,
            context: context
        ))
    }

    /// Инициализация через ReviewTier для экрана повторения
    init(tier: ReviewTier, context: ModelContext) {
        self.categories = []
        self.isReviewMode = true
        _viewModel = StateObject(wrappedValue: FlashcardViewModel(tier: tier, context: context))
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                if viewModel.isFinished {
                    FinishView(
                        remainingNewCards: viewModel.remainingNewCards,
                        onContinue: { viewModel.loadNextBatch() },
                        dismiss: dismiss
                    )
                } else if let word = viewModel.currentWord {
                    cardContent(for: word)
                } else {
                    ProgressView().tint(.orange)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Выйти из урока?", isPresented: $showExitAlert) {
            Button("Продолжить", role: .cancel) {}
            Button("Выйти", role: .destructive) { dismiss() }
        } message: {
            Text("Прогресс текущей сессии не будет засчитан.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 15) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(Color.orange)
                        .frame(width: geo.size.width * viewModel.progress)
                        .animation(.easeInOut, value: viewModel.progress)
                }
            }
            .frame(height: 6)

            Button(action: {
                if viewModel.isFinished {
                    dismiss()
                } else {
                    showExitAlert = true
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func cardContent(for word: VocabItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.polish)
                        .font(.system(size: 38, weight: .bold))
                    
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Button(action: { SpeechService.shared.speak(word.polish, language: "pl-PL") }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .padding(14)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            Text(word.translation.uppercased())
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 20)
            
            if !word.example.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PRZYKŁAD").font(.caption2).bold().foregroundColor(.secondary)
                    Text(word.example)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(15)
                }
            }
            
            Spacer()
            
            // FSRS БЛОК КНОПОК
            HStack(spacing: 10) {
                ratingButton(title: "Снова", color: .red, rating: .again)
                ratingButton(title: "Трудно", color: .orange, rating: .hard)
                ratingButton(title: "Хорошо", color: .green, rating: .good)
                ratingButton(title: "Легко", color: .blue, rating: .easy)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
    }
    
    private func ratingButton(title: String, color: Color, rating: FSRSRating) -> some View {
        Button(action: { viewModel.submitRating(rating) }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(color.opacity(0.15))
            .cornerRadius(16)
        }
    }
}

// MARK: - Вспомогательные компоненты
struct FinishView: View {
    let remainingNewCards: Int
    let onContinue: () -> Void
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            Image(systemName: "star.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.orange)

            VStack(spacing: 10) {
                Text("Отличная работа!")
                    .font(.title).bold()
                Text("Сессия завершена. Интервалы обновлены.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                if remainingNewCards > 0 {
                    Text("Ещё \(remainingNewCards) новых слов в этой теме")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            Spacer()

            VStack(spacing: 12) {
                if remainingNewCards > 0 {
                    Button(action: onContinue) {
                        Text("Продолжить")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(Color.orange).cornerRadius(29)
                    }
                }
                Button(action: { dismiss() }) {
                    Text("Завершить")
                        .font(.headline)
                        .foregroundColor(remainingNewCards > 0 ? .secondary : .white)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(remainingNewCards > 0 ? Color.clear : Color.orange)
                        .overlay(
                            remainingNewCards > 0 ?
                            RoundedRectangle(cornerRadius: 29).stroke(Color.secondary.opacity(0.3), lineWidth: 1) : nil
                        )
                        .cornerRadius(29)
                }
            }
            .padding(.horizontal, 30).padding(.bottom, 30)
        }
    }
}
