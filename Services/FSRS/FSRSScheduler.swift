import Foundation

/// FSRS-6 algorithm. Ported from open-spaced-repetition/py-fsrs v6.3.1.
/// A pure function over FSRSCardSnapshot, independent of SwiftData.
///
/// Key differences from v4.5:
/// • 21 parameters (was 17). w[20] = adaptive decay.
/// • Short-term stability formula for same-day repeats.
/// • Linear damping in next_difficulty (smoother near the bounds).
/// • Explicit learning_steps / relearning_steps instead of an instant jump to .review.
/// • Forget stability — min(long_term, short_term), so an error isn't "rewarded".
final class FSRSScheduler {

    // MARK: - Defaults (FSRS-6, py-fsrs v6.3.1)

    /// 21 model parameters. w[20] = adaptive decay.
    static let defaultParameters: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
        1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
        1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ]

    /// Learning steps for a new card (seconds). Default 1 min and 10 min.
    static let defaultLearningSteps: [TimeInterval] = [60, 600]

    /// Relearning steps after an error in review (seconds). Default 10 min.
    static let defaultRelearningSteps: [TimeInterval] = [600]

    /// Minimum and maximum stability/difficulty values.
    private static let stabilityMin: Double = 0.001
    private static let difficultyMin: Double = 1.0
    private static let difficultyMax: Double = 10.0

    // MARK: - Configuration

    private let parameters: [Double]
    private let desiredRetention: Double
    private let learningSteps: [TimeInterval]
    private let relearningSteps: [TimeInterval]
    private let maximumInterval: Int

    /// Derived: decay = -w[20], factor = 0.9^(1/decay) - 1.
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

    /// Pure function: returns a new snapshot without mutating the input.
    func schedule(card: FSRSCardSnapshot, rating: FSRSRating, now: Date) -> FSRSCardSnapshot {
        var next = card
        next.lastReview = now
        next.reps += 1

        let elapsedDays = card.lastReview.map { max(0, now.timeIntervalSince($0) / 86400.0) }

        switch card.state {
        case .new:
            // First touch: initialize DSR and enter learning.
            next.stability = initialStability(rating: rating)
            next.difficulty = clampDifficulty(initialDifficulty(rating: rating, clamp: false))
            scheduleStep(card: card, next: &next, rating: rating,
                         steps: learningSteps, targetState: .learning, now: now)

        case .learning, .relearning:
            // Update DSR
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
            // Update DSR
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

    /// learning/relearning step logic per py-fsrs.
    /// targetState — the state the card goes to if it stays in the steps
    /// (learning → .learning, relearning → .relearning).
    private func scheduleStep(card: FSRSCardSnapshot,
                              next: inout FSRSCardSnapshot,
                              rating: FSRSRating,
                              steps: [TimeInterval],
                              targetState: FSRSState,
                              now: Date) {
        let currentStep = (card.state == .new) ? 0 : (card.step ?? 0)

        // Edge: no steps, or we're past the last one and not Again → straight to review.
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

    /// `clamp = false` is needed for arg_1 in mean reversion (Easy without clamping).
    private func initialDifficulty(rating: FSRSRating, clamp: Bool) -> Double {
        let raw = parameters[4] - exp(parameters[5] * Double(rating.rawValue - 1)) + 1.0
        return clamp ? clampDifficulty(raw) : raw
    }

    /// v6: linear damping + mean reversion. Smoother near the bounds [1, 10].
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

    /// v6: forget stability — the minimum of long-term and short-term, so an error
    /// doesn't give a "bonus" over a correct same-day answer.
    private func nextForgetStability(difficulty: Double, stability: Double,
                                     retrievability: Double) -> Double {
        let longTerm = parameters[11]
            * pow(difficulty, -parameters[12])
            * (pow(stability + 1.0, parameters[13]) - 1.0)
            * exp((1.0 - retrievability) * parameters[14])
        let shortTerm = stability / exp(parameters[17] * parameters[18])
        return min(longTerm, shortTerm)
    }

    /// v6: new formula for same-day repeats in learning/review/relearning.
    private func shortTermStability(stability: Double, rating: FSRSRating) -> Double {
        var increase = exp(parameters[17] * (Double(rating.rawValue - 3) + parameters[18]))
                       * pow(stability, -parameters[19])
        if rating == .good || rating == .easy {
            increase = max(increase, 1.0)
        }
        return clampStability(stability * increase)
    }

    /// Interval between reviews in days for a card in .review.
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
