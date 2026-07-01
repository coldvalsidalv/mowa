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

    /// Экзаменационный режим — слова целевого уровня CEFR
    init(level: String, context: ModelContext) {
        self.categories = []
        self.isReviewMode = false
        _viewModel = StateObject(wrappedValue: FlashcardViewModel(level: level, context: context))
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
        .onDisappear { SpeechService.shared.stop() }
        .alert(L("flashcard.exit_title"), isPresented: $showExitAlert) {
            Button(L("common.continue"), role: .cancel) {}
            Button(L("common.exit"), role: .destructive) { dismiss() }
        } message: {
            Text(L("flashcard.exit_message"))
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
                
                Button(action: { SpeechService.shared.speak(word) }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .padding(14)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Text(word.translation.uppercased())
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 20)
            
            if !word.example.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("flashcard.example")).font(.caption2).bold().foregroundColor(.secondary)
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
                ratingButton(title: L("flashcard.again"), color: Color(red: 0.85, green: 0.18, blue: 0.18), rating: .again)
                ratingButton(title: L("flashcard.hard"), color: Color(red: 0.90, green: 0.50, blue: 0.10), rating: .hard)
                ratingButton(title: L("flashcard.good"), color: Color(red: 0.18, green: 0.70, blue: 0.35), rating: .good)
                ratingButton(title: L("flashcard.easy"), color: Color(red: 0.05, green: 0.60, blue: 0.75), rating: .easy)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
    }
    
    private func ratingButton(title: String, color: Color, rating: FSRSRating) -> some View {
        Button(action: { viewModel.submitRating(rating) }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(color)
                .cornerRadius(16)
                .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 3)
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
                Text(L("flashcard.finish_title"))
                    .font(.title).bold()
                Text(L("flashcard.finish_sub"))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                if remainingNewCards > 0 {
                    Text(L("flashcard.more_cards_fmt", remainingNewCards))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            Spacer()

            VStack(spacing: 12) {
                if remainingNewCards > 0 {
                    Button(action: onContinue) {
                        Text(L("common.continue"))
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(Color.orange).cornerRadius(29)
                    }
                }
                Button(action: { dismiss() }) {
                    Text(L("flashcard.finish_btn"))
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
