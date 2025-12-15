import Foundation

class DataLoader {
    static let shared = DataLoader()
    
    private let wordsFileName = "words.json"
    private let grammarFileName = "grammar.json"
    
    // 1. Загрузка Слов
    func loadWords() -> [WordItem] {
        return load(fileName: wordsFileName)
    }
    
    // 2. Загрузка Грамматики (Вот то, что потерялось)
    func loadGrammar() -> [GrammarLesson] {
        return load(fileName: grammarFileName)
    }
    
    // Универсальная функция загрузки
    private func load<T: Decodable>(fileName: String) -> [T] {
        // 1. Пробуем загрузить из папки Документы (если ContentManager скачал обновление)
        let docURL = ContentManager.shared.getLocalFileURL(for: fileName)
        
        if let data = try? Data(contentsOf: docURL) {
            do {
                let decoded = try JSONDecoder().decode([T].self, from: data)
                // print("📂 [DataLoader] Загружено из Documents: \(fileName)")
                return decoded
            } catch {
                print("⚠️ [DataLoader] Файл в Documents поврежден (\(fileName)), пробую Bundle...")
            }
        }
        
        // 2. Если в Документах нет или ошибка — берем из Bundle (вшитый файл)
        // Убираем расширение .json, так как url(forResource:...) просит его отдельно
        let cleanName = fileName.replacingOccurrences(of: ".json", with: "")
        
        if let bundleURL = Bundle.main.url(forResource: cleanName, withExtension: "json") {
            do {
                let data = try Data(contentsOf: bundleURL)
                let decoded = try JSONDecoder().decode([T].self, from: data)
                // print("📦 [DataLoader] Загружено из Bundle: \(fileName)")
                return decoded
            } catch {
                print("❌ [DataLoader] Ошибка декодирования Bundle файла \(fileName): \(error)")
            }
        } else {
            print("❌ [DataLoader] Файл \(fileName) вообще не найден нигде!")
        }
        
        return []
    }
}
