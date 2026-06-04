import Foundation

// MARK: - Response DTOs

struct TeenyListResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let items: [T]
    let total: Int
}

struct RemoteWord: Decodable, Sendable {
    let id: String
    let polish: String
    let translation: String
    let transcription: String?
    let part_of_speech: String?
    let example: String?
    let examples_list: String?   // JSON-строка, декодируем отдельно
    let category: String
    let level: String?
    let image_name: String?

    func toDTO() -> WordItemDTO {
        var examplesList: [String] = []
        if let raw = examples_list,
           let data = raw.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([String].self, from: data) {
            examplesList = parsed
        }
        return WordItemDTO(
            id: 0,
            category: category,
            polish: polish,
            translation: translation,
            transcription: transcription ?? "",
            example: example ?? "",
            imageName: image_name ?? "",
            partOfSpeech: part_of_speech ?? "",
            examplesList: examplesList
        )
    }
}

struct RemoteGrammarLesson: Decodable, Sendable {
    let lesson_id: String
    let title: String
    let description: String?
    let level: String
    let order_index: Int?
    let steps: String          // JSON-строка массива шагов

    func toGrammarLesson() -> GrammarLesson? {
        guard let data = steps.data(using: .utf8),
              let parsedSteps = try? JSONDecoder().decode([GrammarStep].self, from: data) else {
            print("❌ APIClient: failed to decode steps for lesson \(lesson_id)")
            return nil
        }
        return GrammarLesson(
            id: lesson_id,
            title: title,
            description: description ?? "",
            level: level,
            steps: parsedSteps
        )
    }
}

// MARK: - APIClient

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - Vocabulary

    /// Загружает все слова с бэкенда постранично.
    func fetchAllWords() async throws -> [WordItemDTO] {
        let pageSize = 100
        var allWords: [WordItemDTO] = []

        // Сначала получаем total чтобы знать сколько страниц
        let first = try await fetchWords(page: 1, limit: pageSize)
        allWords.append(contentsOf: first.items.map { $0.toDTO() })

        let totalPages = Int(ceil(Double(first.total) / Double(pageSize)))

        if totalPages > 1 {
            try await withThrowingTaskGroup(of: [WordItemDTO].self) { group in
                for p in 2...totalPages {
                    group.addTask { [weak self] in
                        guard let self else { return [] }
                        let resp = try await self.fetchWords(page: p, limit: pageSize)
                        return resp.items.map { $0.toDTO() }
                    }
                }
                for try await batch in group {
                    allWords.append(contentsOf: batch)
                }
            }
        }

        return allWords
    }

    private func fetchWords(page: Int, limit: Int) async throws -> TeenyListResponse<RemoteWord> {
        let body: [String: Any] = ["limit": limit, "offset": (page - 1) * limit]
        return try await post(path: "/api/v1/table/vocabulary/list", body: body)
    }

    // MARK: - Grammar

    func fetchAllGrammarLessons() async throws -> [GrammarLesson] {
        let resp: TeenyListResponse<RemoteGrammarLesson> = try await post(
            path: "/api/v1/table/grammar_lessons/list",
            body: ["limit": 200, "sort": "order_index"]
        )
        return resp.items.compactMap { $0.toGrammarLesson() }
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

        let data: Data
        let response: URLResponse
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
