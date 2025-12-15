import Foundation
import Combine

class ContentManager: ObservableObject {
    static let shared = ContentManager()
    let contentUpdated = PassthroughSubject<Void, Never>()
    
    private init() {}
    
    // Ссылки (настрой позже)
    private let wordsURL = "https://raw.githubusercontent.com/user/repo/main/words.json"
    private let grammarURL = "https://raw.githubusercontent.com/user/repo/main/grammar.json"
    
    // --- НОВЫЙ МЕТОД ДЛЯ СОХРАНЕНИЯ СЛОВ ---
    func saveWords(_ words: [WordItem]) {
        do {
            let data = try JSONEncoder().encode(words)
            if saveToDocuments(data: data, fileName: "words.json") {
                print("💾 [ContentManager] Прогресс слов сохранен локально.")
            }
        } catch {
            print("❌ [ContentManager] Ошибка кодирования слов: \(error)")
        }
    }
    
    func checkForUpdates() {
        downloadJSON(from: wordsURL, fileName: "words.json")
        downloadJSON(from: grammarURL, fileName: "grammar.json")
    }
    
    private func downloadJSON(from urlString: String, fileName: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }
            if self.saveToDocuments(data: data, fileName: fileName) {
                DispatchQueue.main.async { self.contentUpdated.send() }
            }
        }.resume()
    }
    
    private func saveToDocuments(data: Data, fileName: String) -> Bool {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func getLocalFileURL(for fileName: String) -> URL {
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
}
