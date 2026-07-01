import Foundation

// MARK: - DTO

struct RemoteLeaderboardEntry: Decodable, Sendable {
    let id: String
    let user_id: String
    let display_name: String
    let xp: Int
}

// MARK: - Leaderboard

extension APIClient {
    func fetchLeaderboard() async throws -> [RemoteLeaderboardEntry] {
        let resp: TeenyListResponse<RemoteLeaderboardEntry> = try await post(
            path: "/api/v1/table/leaderboard/list",
            body: ["limit": 25, "sort": "-xp"]
        )
        return resp.items
    }

    /// Upsert: insert → on unique user_id conflict → update.
    func upsertLeaderboard(userId: String, displayName: String, xp: Int) async throws {
        let insertBody: [String: Any] = [
            "values": ["user_id": userId, "display_name": displayName, "xp": xp]
        ]
        do {
            let _: TeenyEmpty = try await post(path: "/api/v1/table/leaderboard/insert", body: insertBody)
        } catch APIError.serverError(let code, let message)
            where code == 409 || (code == 400 && message?.localizedCaseInsensitiveContains("unique") == true) {
            let updateBody: [String: Any] = [
                "where": "user_id == \"\(userId)\"",
                "values": ["display_name": displayName, "xp": xp]
            ]
            let _: TeenyEmpty = try await post(path: "/api/v1/table/leaderboard/update", body: updateBody)
        }
    }
}
