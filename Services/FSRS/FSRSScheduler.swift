import Foundation

/// Математическое ядро FSRS на основе модели DSR (Difficulty, Stability, Retrievability).
/// Чистая функция над снимком — не мутирует входы и не зависит от SwiftData.
/// Версия алгоритма: FSRS-4.5 (decay/factor зафиксированы). v5 — отдельная миграция.
final class FSRSScheduler {
    // Стандартные оптимизированные веса FSRS v4 (17 параметров).
    // TODO (Фаза 3): подтягивать персональные веса с бэкенда после оптимизации
    // по ReviewLog (gradient descent по log-loss).
    private let w: [Double] = [
        0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01,
        1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
    ]

    /// UTC-календарь — устойчив к смене таймзоны устройства и к DST.
    private let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Чистая функция: возвращает новый снимок без мутации входа.
    func schedule(card: FSRSCardSnapshot, rating: FSRSRating, now: Date) -> FSRSCardSnapshot {
        var next = card
        next.lastReview = now
        next.reps += 1

        switch card.state {
        case .new:
            next.difficulty = initDifficulty(rating: rating)
            next.stability  = initStability(rating: rating)
            next.state      = (rating == .again) ? .learning : .review

        case .learning, .relearning:
            next.difficulty = nextDifficulty(d: card.difficulty, rating: rating)
            next.stability  = initStability(rating: rating)
            next.state      = (rating == .again) ? card.state : .review

        case .review:
            next.difficulty = nextDifficulty(d: card.difficulty, rating: rating)
            let elapsedDays    = max(0, now.timeIntervalSince(card.lastReview ?? now) / 86400.0)
            let retrievability = currentRetrievability(s: card.stability, t: elapsedDays)

            if rating == .again {
                next.lapses    += 1
                next.stability  = nextForgetStability(d: next.difficulty, s: card.stability, r: retrievability)
                next.state      = .relearning
            } else {
                next.stability  = nextRecallStability(d: next.difficulty, s: card.stability, r: retrievability, rating: rating)
            }
        }

        let nextIntervalDays = nextInterval(s: next.stability)
        next.scheduledDays = nextIntervalDays
        next.due = utcCalendar.date(byAdding: .day, value: nextIntervalDays, to: now)!

        return next
    }

    // MARK: - DSR Math Formulas

    private func initStability(rating: FSRSRating) -> Double {
        return max(w[rating.rawValue - 1], 0.1)
    }

    private func initDifficulty(rating: FSRSRating) -> Double {
        return min(max(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1, 1.0), 10.0)
    }

    private func nextDifficulty(d: Double, rating: FSRSRating) -> Double {
        let nextD = d - w[6] * Double(rating.rawValue - 3)
        // Mean reversion: предотвращение "ease hell"
        return min(max(w[7] * initDifficulty(rating: .good) + (1 - w[7]) * nextD, 1.0), 10.0)
    }

    private func currentRetrievability(s: Double, t: Double) -> Double {
        let decay = -0.5
        let factor = 19.0 / 81.0
        return pow(1.0 + factor * (t / s), decay)
    }

    private func nextRecallStability(d: Double, s: Double, r: Double, rating: FSRSRating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus   = rating == .easy ? w[16] : 1.0

        let inc = exp(w[8])
            * (11.0 - d)
            * pow(s, -w[9])
            * (exp((1.0 - r) * w[10]) - 1.0)
            * hardPenalty * easyBonus

        return min(s * (1.0 + inc), 36500.0) // Лимит в 100 лет
    }

    private func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        return min(max(w[11] * pow(d, -w[12]) * pow(s + 1.0, w[13]) * exp((1.0 - r) * w[14]), 0.1), s)
    }

    private func nextInterval(s: Double) -> Int {
        let factor = 19.0 / 81.0
        let retention = VerbumConfig.fsrsDesiredRetention
        let interval = (s / factor) * (pow(retention, -2.0) - 1.0)
        return max(1, Int(round(interval)))
    }
}
