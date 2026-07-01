import Foundation

// MARK: - DTO

/// Raw DTO from the backend. JSON columns arrive as strings (like inflections in
/// RemoteWord) — parsed in toParams().
struct RemoteFSRSParams: Decodable, Sendable {
    let id: String
    let user_id: String
    let parameters: String         // JSON-encoded [Double]
    let desired_retention: Double
    let learning_steps: String     // JSON-encoded [Double]
    let relearning_steps: String   // JSON-encoded [Double]

    func toParams() throws -> FSRSParams {
        let dec = JSONDecoder()
        guard let pData = parameters.data(using: .utf8),
              let lsData = learning_steps.data(using: .utf8),
              let rsData = relearning_steps.data(using: .utf8) else {
            throw APIError.decodingError(NSError(domain: "FSRSParams", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "non-utf8 JSON"]))
        }
        return FSRSParams(
            parameters: try dec.decode([Double].self, from: pData),
            desiredRetention: desired_retention,
            learningSteps: try dec.decode([TimeInterval].self, from: lsData),
            relearningSteps: try dec.decode([TimeInterval].self, from: rsData)
        )
    }
}

// MARK: - FSRS Params

extension APIClient {
    /// Fetches the user's personal FSRS params. nil — no record exists, so we use defaults.
    func fetchFsrsParams(userId: String) async throws -> FSRSParams? {
        let body: [String: Any] = [
            "where": "user_id == \"\(userId)\"",
            "limit": 1
        ]
        let resp: TeenyListResponse<RemoteFSRSParams> = try await post(
            path: "/api/v1/table/fsrs_params/list", body: body
        )
        guard let remote = resp.items.first else { return nil }
        return try remote.toParams()
    }
}
