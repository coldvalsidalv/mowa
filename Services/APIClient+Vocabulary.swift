import Foundation

// MARK: - DTO

struct RemoteWord: Sendable {
    let id: String
    let polish: String
    let translation: String
    let transcription: String?
    let part_of_speech: String?
    let example: String?
    let examples_list: String?
    let category: String
    let image_name: String?
    let updated: String?
    let rank: Int?
    let inflections: String?
}

extension RemoteWord: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, polish, translation, transcription, category, updated, rank, inflections
        case part_of_speech, example, examples_list, image_name
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id           = try container.decode(String.self, forKey: .id)
        polish       = try container.decode(String.self, forKey: .polish)
        translation  = try container.decode(String.self, forKey: .translation)
        transcription  = try container.decodeIfPresent(String.self, forKey: .transcription)
        part_of_speech = try container.decodeIfPresent(String.self, forKey: .part_of_speech)
        example        = try container.decodeIfPresent(String.self, forKey: .example)
        examples_list  = try container.decodeIfPresent(String.self, forKey: .examples_list)
        category       = try container.decode(String.self, forKey: .category)
        image_name     = try container.decodeIfPresent(String.self, forKey: .image_name)
        updated        = try container.decodeIfPresent(String.self, forKey: .updated)
        rank           = try container.decodeIfPresent(Int.self, forKey: .rank)
        inflections    = try container.decodeIfPresent(String.self, forKey: .inflections)
    }
}

// MARK: - Vocabulary

extension APIClient {
    /// Загружает все слова (полный sync при первом запуске)
    func fetchAllWords() async throws -> [RemoteWord] {
        try await fetchWords(updatedSince: nil)
    }

    /// Загружает только слова обновлённые после `since` (delta sync)
    func fetchWordsDelta(since: Date) async throws -> [RemoteWord] {
        try await fetchWords(updatedSince: since)
    }

    private func fetchWords(updatedSince: Date?) async throws -> [RemoteWord] {
        let pageSize = 200
        var body: [String: Any] = ["limit": pageSize, "offset": 0]
        if let since = updatedSince {
            let formatted = ISO8601DateFormatter.teenybase.string(from: since)
            body["where"] = "updated > \"\(formatted)\""
        }

        let first: TeenyListResponse<RemoteWord> = try await post(
            path: "/api/v1/table/vocabulary/list", body: body)
        var all = first.items

        let totalPages = Int(ceil(Double(first.total) / Double(pageSize)))
        if totalPages > 1 {
            try await withThrowingTaskGroup(of: [RemoteWord].self) { group in
                for page in 2...totalPages {
                    group.addTask { [weak self] in
                        guard let self else { return [] }
                        var pageBody = body
                        pageBody["offset"] = (page - 1) * pageSize
                        let resp: TeenyListResponse<RemoteWord> = try await self.post(
                            path: "/api/v1/table/vocabulary/list", body: pageBody)
                        return resp.items
                    }
                }
                for try await batch in group { all.append(contentsOf: batch) }
            }
        }
        return all
    }
}
