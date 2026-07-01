import Foundation

// MARK: - Account

extension APIClient {
    /// Удаляет запись юзера на бэкенде (правило таблицы: auth.uid == id,
    /// т.е. юзер может удалить только себя). App Store 5.1.1(v) требует
    /// возможность удаления аккаунта прямо из приложения.
    func deleteAccount(userId: String) async throws {
        let body: [String: Any] = ["where": "id == \"\(userId)\""]
        let _: TeenyEmpty = try await post(path: "/api/v1/table/users/delete", body: body)
    }
}
