import Combine
import Foundation

/// Целевой уровень госэкзамена (B1/B2). Выводится из префикса VocabItem.category
/// ("B1 · 4"); A2 как госэкзамен не сдаётся.
enum ExamLevel: String, CaseIterable, Identifiable {
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

/// Официальная сессия госэкзамена. Даты публикует Państwowa Komisja раз в год;
/// официального API нет — датасет поддерживается вручную (бэкенд + bundle-фоллбэк).
struct ExamSession: Identifiable, Hashable, Sendable {
    let id: String            // session_id, напр. "2026-10"
    let startDate: Date       // первый день сессии (суббота)
    let endDate: Date         // второй день (воскресенье)
    let levels: [String]      // уровни для взрослых на этой сессии: ["B1","B2"]

    func offers(_ level: ExamLevel) -> Bool { levels.contains(level.rawValue) }
}

/// DTO из bundle (levels — нативный массив).
struct BundleExamSession: Decodable, Sendable {
    let session_id: String
    let start_date: String
    let end_date: String
    let levels: [String]
}

enum ExamSessionParser {
    nonisolated static func from(_ b: BundleExamSession) -> ExamSession? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let start = f.date(from: b.start_date),
              let end = f.date(from: b.end_date) else { return nil }
        return ExamSession(id: b.session_id, startDate: start, endDate: end, levels: b.levels)
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
}
