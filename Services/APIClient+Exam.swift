import Foundation

// MARK: - DTO

/// Teenybase возвращает json-поля как строки (как steps у грамматики),
/// поэтому levels декодируем строкой и парсим вручную.
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

private func remoteToExamSession(_ r: RemoteExamSession) -> ExamSession? {
    let levels = (r.levels.data(using: .utf8))
        .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    let bundle = BundleExamSession(
        session_id: r.session_id, start_date: r.start_date, end_date: r.end_date, levels: levels
    )
    return ExamSessionParser.from(bundle)
}
