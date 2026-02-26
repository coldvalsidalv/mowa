import SwiftUI

struct VocabularyWord: Identifiable {
    let id = UUID()
    let original: String   // Польское слово
    let translation: String // Русский перевод
}

struct VocabularyView: View {
    let wordsCount: Int
    
    // Демо-данные на польском языке
    let words: [VocabularyWord] = [
        VocabularyWord(original: "Cześć", translation: "Привет"),
        VocabularyWord(original: "Dziękuję", translation: "Спасибо"),
        VocabularyWord(original: "Przepraszam", translation: "Извините"),
        VocabularyWord(original: "Samochód", translation: "Автомобиль"),
        VocabularyWord(original: "Wspaniale", translation: "Замечательно")
    ]
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Всего слов").font(.caption).foregroundColor(.secondary)
                        Text("\(wordsCount)").font(.largeTitle).bold().foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 40)).foregroundColor(.blue.opacity(0.2))
                }
            }
            
            Section("Недавно изученные (Polski)") {
                ForEach(words) { word in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(word.original)
                                .font(.headline)
                            Text(word.translation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(action: {
                            // Вызов озвучки с явным указанием польского языка
                            SpeechService.shared.speak(word.original, language: "pl-PL")
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
        .navigationTitle("Мой словарь")
    }
}
