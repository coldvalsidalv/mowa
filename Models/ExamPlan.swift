import SwiftUI
import Combine

/// Целевой уровень госэкзамена. Привязан к префиксу VocabItem.category ("B1 · 4").
enum ExamLevel: String, CaseIterable, Identifiable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"

    var id: String { rawValue }
    var title: String { rawValue }
}

extension VocabItem {
    /// Уровень CEFR, выведенный из category ("B1 · 4" -> "B1").
    /// Словарь размечен так, что category всегда начинается с уровня —
    /// отдельное поле в модели не нужно.
    var cefrLevel: String {
        String(category.prefix(while: { $0 != " " }))
    }
}

/// Хранит цель подготовки к экзамену (уровень + дата). UserDefaults-backed,
/// без изменений модели/БД. Обратный отсчёт и дневной план считаются поверх.
@MainActor
final class ExamPlanStore: ObservableObject {
    @Published var targetLevel: ExamLevel? {
        didSet { UserDefaults.standard.set(targetLevel?.rawValue, forKey: StorageKeys.examTargetLevel) }
    }
    @Published var examDate: Date? {
        didSet {
            if let d = examDate {
                UserDefaults.standard.set(d.timeIntervalSince1970, forKey: StorageKeys.examDate)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.examDate)
            }
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: StorageKeys.examTargetLevel) {
            self.targetLevel = ExamLevel(rawValue: raw)
        }
        let ts = UserDefaults.standard.double(forKey: StorageKeys.examDate)
        if ts > 0 { self.examDate = Date(timeIntervalSince1970: ts) }
    }

    var isConfigured: Bool { targetLevel != nil && examDate != nil }

    /// Полных дней до экзамена (0 = сегодня, отрицательное = прошёл).
    var daysLeft: Int? {
        guard let examDate else { return nil }
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: examDate)
        return cal.dateComponents([.day], from: from, to: to).day
    }

    /// Официальные сессии госэкзамена B1 в 2026 — подсказки для пикера даты.
    static let officialDates: [Date] = {
        var cal = Calendar(identifier: .gregorian)
        let comps = [
            DateComponents(year: 2026, month: 6, day: 27),
            DateComponents(year: 2026, month: 10, day: 17),
            DateComponents(year: 2026, month: 12, day: 5),
        ]
        return comps.compactMap { cal.date(from: $0) }
    }()
}
