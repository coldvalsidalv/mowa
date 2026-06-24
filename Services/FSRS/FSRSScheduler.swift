import Foundation

/// FSRS-6 алгоритм. Порт из open-spaced-repetition/py-fsrs v6.3.1.
/// Чистая функция над FSRSCardSnapshot, не зависит от SwiftData.
///
/// Ключевые отличия от v4.5:
/// • 21 параметр (был 17). w[20] = adaptive decay.
/// • Short-term stability формула для same-day повторов.
/// • Linear damping в next_difficulty (плавнее у пределов).
/// • Явные learning_steps / relearning_steps вместо мгновенного перехода в .review.
/// • Forget stability — min(long_term, short_term), чтобы не "награждать" ошибку.
final class FSRSScheduler {

    // MARK: - Defaults (FSRS-6, py-fsrs v6.3.1)

    /// 21 параметр модели. w[20] = adaptive decay.
    static let defaultParameters: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
        1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
        1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ]

    /// Шаги обучения новой карточки (секунды). По умолчанию 1 мин и 10 мин.
    static let defaultLearningSteps: [TimeInterval] = [60, 600]

    /// Шаги переучивания после ошибки в review (секунды). По умолчанию 10 мин.
    static let defaultRelearningSteps: [TimeInterval] = [600]

    /// Минимальное и максимальное значения stability/difficulty.
    private static let stabilityMin: Double = 0.001
    private static let difficultyMin: Double = 1.0
    private static let difficultyMax: Double = 10.0

    // MARK: - Configuration

    private let parameters: [Double]
    private let desiredRetention: Double
    private let learningSteps: [TimeInterval]
    private let relearningSteps: [TimeInterval]
    private let maximumInterval: Int

    /// Производные: decay = -w[20], factor = 0.9^(1/decay) - 1.
    private let decay: Double
    private let factor: Double

    init(parameters: [Double] = FSRSScheduler.defaultParameters,
         desiredRetention: Double = VerbumConfig.fsrsDesiredRetention,
         learningSteps: [TimeInterval] = FSRSScheduler.defaultLearningSteps,
         relearningSteps: [TimeInterval] = FSRSScheduler.defaultRelearningSteps,
         maximumInterval: Int = 36500) {
        precondition(parameters.count == 21,
                     "FSRS-6 expects 21 parameters, got \(parameters.count)")
        self.parameters = parameters
        self.desiredRetention = desiredRetention
        self.learningSteps = learningSteps
        self.relearningSteps = relearningSteps
        self.maximumInterval = maximumInterval

        self.decay = -parameters[20]
        self.factor = pow(0.9, 1.0 / self.decay) - 1.0
    }

    // MARK: - Public API

    /// Чистая функция: возвращает новый снимок без мутации входа.
    func schedule(card: FSRSCardSnapshot, rating: FSRSRating, now: Date) -> FSRSCardSnapshot {
        var next = card
        next.lastReview = now
        next.reps += 1

        let elapsedDays = card.lastReview.map { max(0, now.timeIntervalSince($0) / 86400.0) }

        switch card.state {
        case .new:
            // Первое касание: инициализируем DSR и заходим в learning.
            next.stability = initialStability(rating: rating)
            next.difficulty = clampDifficulty(initialDifficulty(rating: rating, clamp: false))
            scheduleStep(card: card, next: &next, rating: rating,
                         steps: learningSteps, targetState: .learning, now: now)

        case .learning, .relearning:
            // Обновление DSR
            if let elapsed = elapsedDays, elapsed < 1.0 {
                next.stability = shortTermStability(stability: card.stability, rating: rating)
            } else {
                let r = currentRetrievability(stability: card.stability,
                                              elapsedDays: elapsedDays ?? 0)
                next.stability = nextStability(difficulty: card.difficulty,
                                               stability: card.stability,
                                               retrievability: r,
                                               rating: rating)
            }
            next.difficulty = nextDifficulty(difficulty: card.difficulty, rating: rating)

            let steps = (card.state == .relearning) ? relearningSteps : learningSteps
            scheduleStep(card: card, next: &next, rating: rating,
                         steps: steps, targetState: card.state, now: now)

        case .review:
            // Обновление DSR
            if let elapsed = elapsedDays, elapsed < 1.0 {
                next.stability = shortTermStability(stability: card.stability, rating: rating)
            } else {
                let r = currentRetrievability(stability: card.stability,
                                              elapsedDays: elapsedDays ?? 0)
                next.stability = nextStability(difficulty: card.difficulty,
                                               stability: card.stability,
                                               retrievability: r,
                                               rating: rating)
            }
            next.difficulty = nextDifficulty(difficulty: card.difficulty, rating: rating)

            switch rating {
            case .again:
                next.lapses += 1
                if relearningSteps.isEmpty {
                    promoteToReview(next: &next, now: now)
                } else {
                    next.state = .relearning
                    next.step = 0
                    next.due = now.addingTimeInterval(relearningSteps[0])
                }
            case .hard, .good, .easy:
                promoteToReview(next: &next, now: now)
            }
        }

        return next
    }

    // MARK: - Step scheduling (Learning / Relearning)

    /// Логика learning/relearning steps по py-fsrs.
    /// targetState — состояние, в которое уходит карта если остаётся в шагах
    /// (учим → .learning, переучиваем → .relearning).
    private func scheduleStep(card: FSRSCardSnapshot,
                              next: inout FSRSCardSnapshot,
                              rating: FSRSRating,
                              steps: [TimeInterval],
                              targetState: FSRSState,
                              now: Date) {
        let currentStep = (card.state == .new) ? 0 : (card.step ?? 0)

        // Edge: нет шагов или мы уже за последним и не Again → сразу в review.
        if steps.isEmpty || (currentStep >= steps.count && rating != .again) {
            promoteToReview(next: &next, now: now)
            return
        }

        switch rating {
        case .again:
            next.state = targetState
            next.step = 0
            next.due = now.addingTimeInterval(steps[0])

        case .hard:
            next.state = targetState
            next.step = currentStep
            let interval: TimeInterval
            if currentStep == 0 && steps.count == 1 {
                interval = steps[0] * 1.5
            } else if currentStep == 0 && steps.count >= 2 {
                interval = (steps[0] + steps[1]) / 2.0
            } else {
                interval = steps[currentStep]
            }
            next.due = now.addingTimeInterval(interval)

        case .good:
            if currentStep + 1 == steps.count {
                promoteToReview(next: &next, now: now)
            } else {
                next.state = targetState
                next.step = currentStep + 1
                next.due = now.addingTimeInterval(steps[currentStep + 1])
            }

        case .easy:
            promoteToReview(next: &next, now: now)
        }
    }

    private func promoteToReview(next: inout FSRSCardSnapshot, now: Date) {
        next.state = .review
        next.step = nil
        let days = nextIntervalDays(stability: next.stability)
        next.due = now.addingTimeInterval(TimeInterval(days) * 86400.0)
    }

    // MARK: - DSR Math (FSRS-6)

    private func initialStability(rating: FSRSRating) -> Double {
        clampStability(parameters[rating.rawValue - 1])
    }

    /// `clamp = false` нужен для arg_1 в mean reversion (Easy без обрезки).
    private func initialDifficulty(rating: FSRSRating, clamp: Bool) -> Double {
        let raw = parameters[4] - exp(parameters[5] * Double(rating.rawValue - 1)) + 1.0
        return clamp ? clampDifficulty(raw) : raw
    }

    /// v6: linear damping + mean reversion. Плавнее у границ [1, 10].
    private func nextDifficulty(difficulty: Double, rating: FSRSRating) -> Double {
        let delta = -(parameters[6] * Double(rating.rawValue - 3))
        let damped = (10.0 - difficulty) * delta / 9.0
        let arg2 = difficulty + damped
        let arg1 = initialDifficulty(rating: .easy, clamp: false)
        let mean = parameters[7] * arg1 + (1.0 - parameters[7]) * arg2
        return clampDifficulty(mean)
    }

    private func currentRetrievability(stability: Double, elapsedDays: Double) -> Double {
        pow(1.0 + factor * elapsedDays / stability, decay)
    }

    private func nextStability(difficulty: Double, stability: Double,
                               retrievability: Double, rating: FSRSRating) -> Double {
        let raw: Double
        if rating == .again {
            raw = nextForgetStability(difficulty: difficulty,
                                      stability: stability,
                                      retrievability: retrievability)
        } else {
            raw = nextRecallStability(difficulty: difficulty,
                                      stability: stability,
                                      retrievability: retrievability,
                                      rating: rating)
        }
        return clampStability(raw)
    }

    private func nextRecallStability(difficulty: Double, stability: Double,
                                     retrievability: Double, rating: FSRSRating) -> Double {
        let hardPenalty = (rating == .hard) ? parameters[15] : 1.0
        let easyBonus   = (rating == .easy) ? parameters[16] : 1.0
        return stability * (1.0
            + exp(parameters[8])
            * (11.0 - difficulty)
            * pow(stability, -parameters[9])
            * (exp((1.0 - retrievability) * parameters[10]) - 1.0)
            * hardPenalty * easyBonus
        )
    }

    /// v6: forget stability — минимум long-term и short-term, чтобы ошибка не
    /// давала "бонус" по сравнению с правильным same-day ответом.
    private func nextForgetStability(difficulty: Double, stability: Double,
                                     retrievability: Double) -> Double {
        let longTerm = parameters[11]
            * pow(difficulty, -parameters[12])
            * (pow(stability + 1.0, parameters[13]) - 1.0)
            * exp((1.0 - retrievability) * parameters[14])
        let shortTerm = stability / exp(parameters[17] * parameters[18])
        return min(longTerm, shortTerm)
    }

    /// v6: новая формула для same-day повторов в learning/review/relearning.
    private func shortTermStability(stability: Double, rating: FSRSRating) -> Double {
        var increase = exp(parameters[17] * (Double(rating.rawValue - 3) + parameters[18]))
                       * pow(stability, -parameters[19])
        if rating == .good || rating == .easy {
            increase = max(increase, 1.0)
        }
        return clampStability(stability * increase)
    }

    /// Интервал между review в днях для карточки в .review.
    private func nextIntervalDays(stability: Double) -> Int {
        let raw = (stability / factor) * (pow(desiredRetention, 1.0 / decay) - 1.0)
        let rounded = Int(raw.rounded())
        return max(1, min(rounded, maximumInterval))
    }

    private func clampStability(_ s: Double) -> Double {
        max(s, Self.stabilityMin)
    }

    private func clampDifficulty(_ d: Double) -> Double {
        min(max(d, Self.difficultyMin), Self.difficultyMax)
    }
}
