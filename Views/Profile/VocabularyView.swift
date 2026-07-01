import SwiftUI
import SwiftData

struct VocabularyView: View {
    @Query(
        filter: #Predicate<VocabItem> { $0.fsrsData.stability >= 3.0 },
        sort: \VocabItem.polish
    ) private var learnedWords: [VocabItem]

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Всего слов").font(.caption).foregroundColor(.secondary)
                        Text("\(learnedWords.count)").font(.largeTitle).bold().foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 40)).foregroundColor(.blue.opacity(0.2))
                }
            }

            if learnedWords.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed").font(.system(size: 36)).foregroundColor(.secondary)
                        Text("Ещё нет изученных слов").font(.headline).foregroundColor(.secondary)
                        Text("Пройди первый урок и слова появятся здесь").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section("Изученные слова (\(learnedWords.count))") {
                    ForEach(learnedWords) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.polish).font(.headline)
                                Text(word.translation).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                SpeechService.shared.speak(word)
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                                    .padding(10)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Мой словарь")
    }
}
