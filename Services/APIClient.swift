import Foundation

// MARK: - Remote DTOs (чистые контейнеры для JSON-декодинга, без логики)

struct TeenyListResponse<T: Decodable>: Decodable, @unchecked Sendable {
    let items: [T]
    let total: Int
}

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

struct RemoteGrammarLesson: Decodable, Sendable {
    let lesson_id: String
    let title: String
    let description: String?
    let level: String
    let order_index: Int?
    let steps: String
}

// MARK: - Error

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - Vocabulary

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
                        return await resp.items
                    }
                }
                for try await batch in group { all.append(contentsOf: batch) }
            }
        }
        return all
    }

    // MARK: - Grammar

    func fetchAllGrammarLessons() async throws -> [GrammarLesson] {
        let resp: TeenyListResponse<RemoteGrammarLesson> = try await post(
            path: "/api/v1/table/grammar_lessons/list",
            body: ["limit": 200, "sort": "order_index"]
        )
        return resp.items.compactMap { remoteToGrammarLesson($0) }
    }

    // MARK: - Generic POST

    private func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: VerbumConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !VerbumConfig.contentReadToken.isEmpty {
            request.setValue("Bearer \(VerbumConfig.contentReadToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.serverError(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Helpers

extension ISO8601DateFormatter {
    /// Формат дат Teenybase: "2026-06-04 19:10:47" (SQLite CURRENT_TIMESTAMP)
    static let teenybase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withSpaceBetweenDateAndTime, .withTime, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

private func remoteToGrammarLesson(_ r: RemoteGrammarLesson) -> GrammarLesson? {
    guard let data = r.steps.data(using: .utf8),
          let steps = try? JSONDecoder().decode([GrammarStep].self, from: data) else {
        print("❌ APIClient: failed to decode steps for lesson \(r.lesson_id)")
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
