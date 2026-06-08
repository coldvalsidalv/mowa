import Foundation
import Combine

/// Персональные параметры FSRS-6 — то, что приходит из бэкенда после оптимизации.
/// До первой оптимизации (или если бэкенд недоступен) клиент работает на дефолтах.
struct FSRSParams: Codable, Equatable {
    let parameters: [Double]          // 21 вес FSRS-6
    let desiredRetention: Double      // 0.80–0.95 рекомендованный диапазон
    let learningSteps: [TimeInterval] // в секундах
    let relearningSteps: [TimeInterval]

    /// Дефолтные параметры FSRS-6 (py-fsrs v6.3.1).
    static let defaults = FSRSParams(
        parameters: FSRSScheduler.defaultParameters,
        desiredRetention: VerbumConfig.fsrsDesiredRetention,
        learningSteps: FSRSScheduler.defaultLearningSteps,
        relearningSteps: FSRSScheduler.defaultRelearningSteps
    )

    /// Валидация формы перед применением: 21 параметр, retention в адекватном диапазоне.
    var isValid: Bool {
        parameters.count == 21
            && desiredRetention >= 0.5 && desiredRetention <= 0.99
            && !learningSteps.isEmpty
            && learningSteps.allSatisfy { $0 > 0 }
            && relearningSteps.allSatisfy { $0 > 0 }
    }
}

/// Хранилище текущих параметров FSRS. Дефолты вшиты; персональные подгружаются
/// при signIn / app foreground через `FSRSParamSyncService`, кэшируются в UserDefaults
/// чтобы пережить рестарт без обращения к сети.
///
/// LearningEngine берёт `current` в init и создаёт FSRSScheduler с этими параметрами —
/// новая сессия = свежий снимок параметров. Hot-reload в середине сессии намеренно
/// не делаем: оптимизатор работает раз в неделю, лишний риск не нужен.
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

    /// Применить и закэшировать новые параметры. Невалидные молча отбрасываются —
    /// безопаснее остаться на старых, чем сломать математику.
    func update(_ params: FSRSParams) {
        guard params.isValid else {
            print("⚠️ FSRSParamStore: rejecting invalid params \(params)")
            return
        }
        current = params
        lastFetchedAt = Date()
        if let data = try? JSONEncoder().encode(params) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    /// Сбросить на дефолты (например, при signOut).
    func reset() {
        current = .defaults
        lastFetchedAt = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    /// Fire-and-forget pull персональных параметров. Вызывать после signIn /
    /// при app foreground. Молча игнорирует ошибки сети и отсутствие записи —
    /// клиент продолжает работать на дефолтах/кэше.
    func refreshIfNeeded() {
        Task { await refreshFromBackend() }
    }

    private func refreshFromBackend() async {
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else { return }
        do {
            if let params = try await APIClient.shared.fetchFsrsParams(userId: userId) {
                update(params)
                print("✅ FSRSParamStore: applied personal params")
            }
            // params == nil — оптимизатор ещё не отработал, остаёмся на дефолтах/кэше
        } catch {
            print("⚠️ FSRSParamStore: fetch failed — \(error)")
        }
    }
}
