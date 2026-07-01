import Foundation

/// Account deletion: network (Teenybase) + auth-session teardown.
/// Extracted from ProfileViewModel so the VM doesn't orchestrate
/// APIClient / AuthManager / Keychain directly (SRP).
@MainActor
final class AccountService {
    static let shared = AccountService()
    private init() {}

    /// Deletes the account on the backend (if a session exists) and signs out.
    /// Local profile cleanup (avatar, progress, fields) is the caller's job —
    /// that's UI state, not this service's responsibility.
    func deleteAccount() async throws {
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else {
            // No session — nothing to delete server-side, just sign out.
            AuthManager.shared.signOut()
            return
        }
        try await APIClient.shared.deleteAccount(userId: userId)
        AuthManager.shared.signOut()
    }
}
