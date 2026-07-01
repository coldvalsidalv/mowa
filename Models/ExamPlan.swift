import Combine
import Foundation

/// Target state-exam level (B1/B2). Derived from the VocabItem.category prefix
/// ("B1 · 4"); A2 isn't taken as a state exam.
enum ExamLevel: String, CaseIterable, Identifiable {
    case b1 = "B1"
    case b2 = "B2"

    var id: String { rawValue }
    var title: String { rawValue }
}

extension VocabItem {
    /// CEFR level derived from category ("B1 · 4" -> "B1").
    /// The vocabulary is tagged so that category always starts with the level —
    /// no separate field in the model is needed.
    var cefrLevel: String {
        String(category.prefix(while: { $0 != " " }))
    }
}

/// Official state-exam session. Państwowa Komisja publishes the dates once a year;
/// there's no official API — the dataset is maintained manually (backend + bundle fallback).
struct ExamSession: Identifiable, Hashable, Sendable {
    let id: String            // session_id, e.g. "2026-10"
    let startDate: Date       // first day of the session (Saturday)
    let endDate: Date         // second day (Sunday)
    let levels: [String]      // adult levels for this session: ["B1","B2"]

    func offers(_ level: ExamLevel) -> Bool { levels.contains(level.rawValue) }
}

/// Bundle DTO (levels is a native array).
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

/// Stores the exam-prep goal (level + date). UserDefaults-backed, with no model/DB
/// changes. The countdown and daily plan are computed on top of it.
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

    /// Full days until the exam (0 = today, negative = passed).
    var daysLeft: Int? {
        guard let examDate else { return nil }
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: examDate)
        return cal.dateComponents([.day], from: from, to: to).day
    }
}
