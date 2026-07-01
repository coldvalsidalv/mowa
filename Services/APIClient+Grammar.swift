import Foundation

// MARK: - DTO

struct RemoteGrammarLesson: Decodable, Sendable {
    let lesson_id: String
    let title: String
    let description: String?
    let level: String
    let order_index: Int?
    let steps: String
}

// MARK: - Grammar

extension APIClient {
    func fetchAllGrammarLessons() async throws -> [GrammarLesson] {
        let resp: TeenyListResponse<RemoteGrammarLesson> = try await post(
            path: "/api/v1/table/grammar_lessons/list",
            body: ["limit": 200, "sort": "order_index"]
        )
        return resp.items.compactMap { remoteToGrammarLesson($0) }
    }
}

private func remoteToGrammarLesson(_ r: RemoteGrammarLesson) -> GrammarLesson? {
    guard let data = r.steps.data(using: .utf8),
          let steps = try? JSONDecoder().decode([GrammarStep].self, from: data) else {
        verbumLog("❌ APIClient: failed to decode steps for lesson \(r.lesson_id)")
        return nil
    }
    return GrammarLesson(
        id: r.lesson_id,
        title: r.title,
        description: r.description ?? "",
        level: r.level,
        steps: steps
    )
}
