import Foundation

/// Удаление аккаунта: сеть (Teenybase) + разрушение auth-сессии.
/// Вынесено из ProfileViewModel, чтобы VM не оркестрировала
/// APIClient / AuthManager / Keychain напрямую (SRP).
@MainActor
final class AccountService {
    static let shared = AccountService()
    private init() {}

    /// Удаляет аккаунт на бэкенде (если есть сессия) и разлогинивает.
    /// Локальную чистку профиля (аватар, прогресс, поля) делает caller —
    /// это UI-состояние, не зона ответственности сервиса.
    func deleteAccount() async throws {
        guard let userId = KeychainHelper.load(KeychainKeys.userId) else {
            // Сессии нет — на сервере удалять нечего, просто разлогиниваемся.
            AuthManager.shared.signOut()
            return
        }
        try await APIClient.shared.deleteAccount(userId: userId)
        AuthManager.shared.signOut()
    }
}
