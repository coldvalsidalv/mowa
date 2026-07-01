import Foundation

// MARK: - Account

extension APIClient {
    /// Deletes the user's record on the backend (table rule: auth.uid == id,
    /// i.e. a user can only delete themselves). App Store 5.1.1(v) requires
    /// account deletion to be available from within the app.
    func deleteAccount(userId: String) async throws {
        let body: [String: Any] = ["where": "id == \"\(userId)\""]
        let _: TeenyEmpty = try await post(path: "/api/v1/table/users/delete", body: body)
    }
}
