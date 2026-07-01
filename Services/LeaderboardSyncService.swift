import Foundation

/// Syncs the current user's XP and name into the public leaderboard table.
/// Throttle: at most once every 5 minutes. Fire-and-forget.
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

        // Clamp to 32 Unicode scalars — matches SQLite length() which counts scalars, not grapheme clusters.
        let rawName = (UserDefaults.standard.string(forKey: StorageKeys.userName) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = String(rawName.unicodeScalars.prefix(32))
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
