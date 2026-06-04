import Foundation

// MARK: - Remote DTOs (чистые контейнеры для JSON-декодинга, без логики)

struct TeenyListResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
}

struct RemoteWord: Sendable {
    let polish: String
    let translation: String
    let transcription: String?
    let part_of_speech: String?
    let example: String?
    let examples_list: String?
    let category: String
    let image_name: String?
}

extension RemoteWord: Decodable {
    enum CodingKeys: String, CodingKey {
        case polish, translation, transcription, category
        case part_of_speech, example, examples_list, image_name
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        polish       = try c.decode(String.self, forKey: .polish)
        translation  = try c.decode(String.self, forKey: .translation)
        transcription  = try c.decodeIfPresent(String.self, forKey: .transcription)
        part_of_speech = try c.decodeIfPresent(String.self, forKey: .part_of_speech)
        example        = try c.decodeIfPresent(String.self, forKey: .example)
        examples_list  = try c.decodeIfPresent(String.self, forKey: .examples_list)
        category       = try c.decode(String.self, forKey: .category)
        image_name     = try c.decodeIfPresent(String.self, forKey: .image_name)
    }
}

struct RemoteGrammarLesson: Decodable {
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

    func fetchAllWords() async throws -> [WordItemDTO] {
        let pageSize = 100
        let first = try await fetchWords(page: 1, limit: pageSize)
        var allRemote = first.items

        let totalPages = Int(ceil(Double(first.total) / Double(pageSize)))
        if totalPages > 1 {
            try await withThrowingTaskGroup(of: [RemoteWord].self) { group in
                for p in 2...totalPages {
                    group.addTask { [weak self] in
                        guard let self else { return [] }
                        return try await self.fetchWords(page: p, limit: pageSize).items
                    }
                }
                for try await batch in group {
                    allRemote.append(contentsOf: batch)
                }
            }
        }

        return allRemote.map { remoteWordToDTO($0) }
    }

    private func fetchWords(page: Int, limit: Int) async throws -> TeenyListResponse<RemoteWord> {
        try await post(path: "/api/v1/table/vocabulary/list",
                       body: ["limit": limit, "offset": (page - 1) * limit])
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

// MARK: - Conversion (вне structs — нет actor-изоляции)

private func remoteWordToDTO(_ r: RemoteWord) -> WordItemDTO {
    var examplesList: [String] = []
    if let raw = r.examples_list,
       let data = raw.data(using: .utf8),
       let parsed = try? JSONDecoder().decode([String].self, from: data) {
        examplesList = parsed
    }
    return WordItemDTO(
        id: 0,
        category: r.category,
        polish: r.polish,
        translation: r.translation,
        transcription: r.transcription ?? "",
        example: r.example ?? "",
        imageName: r.image_name ?? "",
        partOfSpeech: r.part_of_speech ?? "",
        examplesList: examplesList
    )
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
