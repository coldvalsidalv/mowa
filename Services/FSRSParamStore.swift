import Foundation
import Combine

/// Personal FSRS-6 params — what comes from the backend after optimization.
/// Before the first optimization (or if the backend is unavailable) the client runs on defaults.
struct FSRSParams: Codable, Equatable {
    let parameters: [Double]          // 21 FSRS-6 weights
    let desiredRetention: Double      // 0.80–0.95 recommended range
    let learningSteps: [TimeInterval] // in seconds
    let relearningSteps: [TimeInterval]

    /// Default FSRS-6 params (py-fsrs v6.3.1).
    static let defaults = FSRSParams(
        parameters: FSRSScheduler.defaultParameters,
        desiredRetention: VerbumConfig.fsrsDesiredRetention,
        learningSteps: FSRSScheduler.defaultLearningSteps,
        relearningSteps: FSRSScheduler.defaultRelearningSteps
    )

    /// Shape validation before applying: 21 params, retention in a sane range.
    var isValid: Bool {
        parameters.count == 21
            && desiredRetention >= 0.5 && desiredRetention <= 0.99
            && !learningSteps.isEmpty
            && learningSteps.allSatisfy { $0 > 0 }
            && relearningSteps.allSatisfy { $0 > 0 }
    }
}

/// Store of the current FSRS params. Defaults are baked in; personal ones are loaded
/// on signIn / app foreground via `FSRSParamSyncService` and cached in UserDefaults
/// to survive a restart without hitting the network.
///
/// LearningEngine takes `current` in init and creates an FSRSScheduler with those params —
/// a new session = a fresh param snapshot. We deliberately avoid a mid-session hot-reload:
/// the optimizer runs once a week, the extra risk isn't worth it.
@MainActor
final class FSRSParamStore: ObservableObject {
    static let shared = FSRSParamStore()

    @Published private(set) var current: FSRSParams = .defaults
    @Published private(set) var lastFetchedAt: Date?

    private let cacheKey = "fsrsParamsCache_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(FSRSParams.self, from: data),
           cached.isValid {
            self.current = cached
        }
    }

    /// Apply and cache new params. Invalid ones are silently dropped —
    /// safer to keep the old ones than to break the math.
    func update(_ params: FSRSParams) {
        guard params.isValid else {
            verbumLog("⚠️ FSRSParamStore: rejecting invalid params \(params)")
            return
        }
        current = params
        lastFetchedAt = Date()
        if let data = try? JSONEncoder().encode(params) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    /// Reset to defaults (e.g. on signOut).
    func reset() {
        current = .defaults
        lastFetchedAt = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    /// Fire-and-forget pull of personal params. Call after signIn / on app foreground.
    /// Silently ignores network errors and a missing record — the client keeps
    /// running on defaults/cache.
    func refreshIfNeeded() {
        Task { await refreshFromBackend() }
    }

    private func refreshFromBackend() async {
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else { return }
        do {
            if let params = try await APIClient.shared.fetchFsrsParams(userId: userId) {
                update(params)
                verbumLog("✅ FSRSParamStore: applied personal params")
            }
            // params == nil — the optimizer hasn't run yet, stay on defaults/cache
        } catch {
            verbumLog("⚠️ FSRSParamStore: fetch failed — \(error)")
        }
    }
}
