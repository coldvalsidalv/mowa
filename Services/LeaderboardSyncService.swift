import Foundation

/// Синхронизирует XP и имя текущего юзера в публичную таблицу leaderboard.
/// Throttle: не чаще раза в 5 минут. Fire-and-forget.
@MainActor
final class LeaderboardSyncService {
    static let shared = LeaderboardSyncService()
    private init() {}

    private var isSyncing = false
    private let throttleKey = "leaderboardSyncedAt"
    private let throttleInterval: TimeInterval = 300

    func syncIfNeeded() {
        Task { await sync() }
    }

    private func sync() async {
        guard !isSyncing else { return }
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else { return }

        let xp = UserDefaults.standard.integer(forKey: StorageKeys.userXP)
        guard xp > 0 else { return }

        // Name goes into the public leaderboard — trim to 32 chars (matches the
        // server-side CHECK) so the table can't be flooded with huge strings.
        let displayName = String(
            (UserDefaults.standard.string(forKey: StorageKeys.userName) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(32)
        )
        guard !displayName.isEmpty else { return }

        let lastSync = UserDefaults.standard.object(forKey: throttleKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastSync) > throttleInterval else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await APIClient.shared.upsertLeaderboard(userId: userId, displayName: displayName, xp: xp)
            UserDefaults.standard.set(Date(), forKey: throttleKey)
            verbumLog("✅ LeaderboardSync: synced \(xp) XP for \(displayName)")
        } catch {
            verbumLog("⚠️ LeaderboardSync: \(error)")
        }
    }
}
