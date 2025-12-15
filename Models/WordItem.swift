import Foundation

struct WordItem: Identifiable, Codable, Hashable {
    let id: Int
    let category: String
    let polish: String
    let translation: String
    let transcription: String
    let example: String
    let imageName: String
    let partOfSpeech: String
    let examplesList: [String]

    // --- SRS (Добавлено как опционально, чтобы старый JSON читался) ---
    // Если в JSON этих полей нет, они будут nil (считаем за 0)
    var box: Int?
    var nextReview: Int?
    var lastReview: Int?
    
    // Хелперы для безопасности, чтобы в коде не писать везде ?? 0
    var safeBox: Int {
        get { box ?? 0 }
        set { box = newValue }
    }
    
    var safeNextReview: Int {
        get { nextReview ?? 0 }
        set { nextReview = newValue }
    }
    
    var safeLastReview: Int {
        get { lastReview ?? 0 }
        set { lastReview = newValue }
    }
}
