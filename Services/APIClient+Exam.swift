import Foundation

// MARK: - DTO

/// Teenybase returns JSON fields as strings (like grammar's steps), so we decode
/// levels as a string and parse it manually.
struct RemoteExamSession: Decodable, Sendable {
    let session_id: String
    let start_date: String
    let end_date: String
    let levels: String
}

// MARK: - Exam sessions

extension APIClient {
    func fetchAllExamSessions() async throws -> [ExamSession] {
        let resp: TeenyListResponse<RemoteExamSession> = try await post(
            path: "/api/v1/table/exam_sessions/list",
            body: ["limit": 100, "sort": "start_date"]
        )
        return resp.items.compactMap { remoteToExamSession($0) }
    }
}

private func remoteToExamSession(_ remote: RemoteExamSession) -> ExamSession? {
    let levels = (remote.levels.data(using: .utf8))
        .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    let bundle = BundleExamSession(
        session_id: remote.session_id, start_date: remote.start_date, end_date: remote.end_date, levels: levels
    )
    return ExamSessionParser.from(bundle)
}
