import Foundation
import SwiftData

@MainActor
final class DatabaseSeeder {
    static let shared = DatabaseSeeder()
    
    // Ключ для предотвращения повторной загрузки при последующих запусках
    private let seedKey = "isDatabaseSeeded_v1"
    
    private init() {}
    
    func seedIfNeeded(context: ModelContext) {
        // Проверка: была ли база уже заполнена ранее
        guard !UserDefaults.standard.bool(forKey: seedKey) else {
            return
        }
        
        print("Начинаю первичную миграцию данных в SwiftData...")
        
        // Чтение сырых DTO из бандла приложения
        let oldWords = DataManager.shared.loadInitialWordsFromBundle()
        
        guard !oldWords.isEmpty else {
            print("❌ Ошибка: JSON words.json пуст или не найден в Bundle.")
            return
        }
        
        // Маппинг DTO в реляционные модели SwiftData
        for dto in oldWords {
            let newItem = VocabItem(
                polish: dto.polish,
                translation: dto.translation,
                partOfSpeech: dto.partOfSpeech,
                example: dto.example,
                category: dto.category
            )
            
            // Если в JSON были сохранены старые прогрессы (коробки), делаем грубую аппроксимацию для FSRS
            if let box = dto.box, box > 0 {
                newItem.fsrsData.state = .review
                newItem.fsrsData.stability = Double(box * 2) // Базовый перевод коробки в дни стабильности
                newItem.fsrsData.difficulty = 5.0 // Средняя сложность
            }
            
            context.insert(newItem)
        }
        
        do {
            try context.save()
            // Устанавливаем флаг успешной миграции
            UserDefaults.standard.set(true, forKey: seedKey)
            print("✅ Миграция успешно завершена. В базу добавлено \(oldWords.count) слов.")
        } catch {
            print("❌ Критическая ошибка сохранения SwiftData при сидировании: \(error)")
        }
    }
}
