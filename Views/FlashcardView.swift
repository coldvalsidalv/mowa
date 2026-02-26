import SwiftUI
import AVFoundation
import Combine

struct FlashcardView: View {
    let categories: [String]
    let isReviewMode: Bool
    
    @StateObject var viewModel: FlashcardViewModel
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    init(categories: [String], isReviewMode: Bool) {
        self.categories = categories
        self.isReviewMode = isReviewMode
        _viewModel = StateObject(wrappedValue: FlashcardViewModel(
            categories: categories,
            isReviewMode: isReviewMode
        ))
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.3))
                            Capsule().fill(Color.orange)
                                .frame(width: geo.size.width * viewModel.progress)
                                .animation(.spring(), value: viewModel.progress)
                        }
                    }
                    .frame(height: 4)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    .padding(.leading, 10)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 40)
                
                if viewModel.isFinished {
                    FinishView(dismiss: dismiss)
                } else if let word = viewModel.currentWord {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text(word.polish)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                SpeechService.shared.speak(word.polish, language: "pl-PL")
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Text(word.translation.uppercased())
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if !word.partOfSpeech.isEmpty {
                            Text(word.partOfSpeech)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary.opacity(0.8))
                                .italic()
                        }
                        
                        Spacer().frame(height: 30)
                        
                        if !word.examplesList.isEmpty || !word.example.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Примеры использования")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    if !word.examplesList.isEmpty {
                                        ForEach(word.examplesList, id: \.self) { example in
                                            ExampleRow(text: example)
                                        }
                                    } else {
                                        ExampleRow(text: word.example)
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.processAnswer(isCorrect: true)
                        }) {
                            Text("Далее")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.orange)
                                .cornerRadius(28)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 24)
                    
                } else {
                    ProgressView().tint(.orange)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Вспомогательные View

struct ExampleRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color.orange).frame(width: 6, height: 6).padding(.top, 6)
            Text(text).font(.system(size: 16)).foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FinishView: View {
    let dismiss: DismissAction
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "trophy.fill").font(.system(size: 80)).foregroundColor(.yellow)
            Text("Отлично!").font(.largeTitle).bold().foregroundColor(.primary)
            Text("Ты прошел все слова на сегодня.").foregroundColor(.secondary)
            Spacer()
            Button(action: { dismiss() }) {
                Text("Завершить").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.orange).cornerRadius(28)
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
    }
}
