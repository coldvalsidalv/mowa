import SwiftUI

struct FlashcardView: View {
    let categories: [String]
    let isReviewMode: Bool
    
    @StateObject var viewModel: FlashcardViewModel
    @Environment(\.dismiss) var dismiss
    
    init(categories: [String], isReviewMode: Bool) {
        self.categories = categories
        self.isReviewMode = isReviewMode
        _viewModel = StateObject(wrappedValue: FlashcardViewModel(categories: categories, isReviewMode: isReviewMode))
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                if viewModel.isFinished {
                    FinishView(dismiss: dismiss)
                } else if let word = viewModel.currentWord {
                    cardContent(for: word)
                } else {
                    ProgressView().tint(.orange)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var topBar: some View {
        HStack(spacing: 15) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(Color.orange)
                        .frame(width: geo.size.width * viewModel.progress)
                }
            }
            .frame(height: 6)
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func cardContent(for word: WordItem) -> some View {
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
            
            HStack(spacing: 16) {
                Button(action: { viewModel.processAnswer(isCorrect: false) }) {
                    Text("Не знаю")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(28)
                }
                
                Button(action: { viewModel.processAnswer(isCorrect: true) }) {
                    Text("Знаю")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.orange)
                        .cornerRadius(28)
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Вспомогательные компоненты в одном файле для избежания ошибок Scope

struct FinishView: View {
    let dismiss: DismissAction
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            Image(systemName: "star.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.orange)
            
            VStack(spacing: 10) {
                Text("Отличная работа!")
                    .font(.title)
                    .bold()
                Text("Все карточки на сегодня пройдены.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Завершить")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.orange)
                    .cornerRadius(29)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }
}
