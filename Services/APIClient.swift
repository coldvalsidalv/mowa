import Foundation

// MARK: - Remote DTOs (чистые контейнеры для JSON-декодинга, без логики)

nonisolated struct TeenyListResponse<T: Decodable>: Decodable, @unchecked Sendable {
    let items: [T]
    let total: Int
}

/// Заглушка для endpoint'ов, ответ которых нам не нужен парсить.
/// Кастомный init принимает любой JSON (объект, массив, скаляр) —
/// синтезированный падал бы на не-объектах.
struct TeenyEmpty: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}

/// Сырой DTO с бэкенда. JSON-столбцы приходят как строки (как inflections в RemoteWord) —
/// парсим в toParams().
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

/// Teenybase возвращает json-поля как строки (как steps у грамматики),
/// поэтому levels декодируем строкой и парсим вручную.
struct RemoteExamSession: Decodable, Sendable {
    let session_id: String
    let start_date: String
    let end_date: String
    let levels: String
}

// MARK: - Error

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, message: String?)
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
                        return resp.items
                    }
                }
                for try await batch in group { all.append(contentsOf: batch) }
            }
        }
        return all
    }

    // MARK: - FSRS Params

    /// Тянет персональные FSRS-параметры юзера. nil — записи нет, значит используем дефолты.
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

    // MARK: - Review Logs

    /// Загружает один ReviewLog на бэкенд. Идемпотентно — при коллизии
    /// (user_id, card_id, review_date) сервер вернёт 4xx, мы трактуем это как success.
    /// `cardId` — Teenybase UUID карточки (remoteId), не локальный SwiftData UUID.
    func insertReviewLog(userId: String,
                         cardId: String,
                         rating: Int,
                         reviewDate: Date,
                         reviewDurationMs: Int) async throws {
        let body: [String: Any] = [
            "values": [
                "user_id": userId,
                "card_id": cardId,
                "rating": rating,
                "review_date": ISO8601DateFormatter.teenybase.string(from: reviewDate),
                "review_duration_ms": reviewDurationMs
            ]
        ]
        do {
            let _: TeenyEmpty = try await post(path: "/api/v1/table/review_logs/insert", body: body)
        } catch APIError.serverError(let code, let message)
            where code == 409 || (code == 400 && message?.localizedCaseInsensitiveContains("unique") == true) {
            // Unique constraint (user_id, card_id, review_date) — повторный синк того же
            // лога, трактуем как success. Любые другие ошибки (401, валидация и т.д.)
            // пробрасываем: caller не должен продвигать cursor, иначе лог потерян навсегда.
        }
    }

    // MARK: - Account

    /// Удаляет запись юзера на бэкенде (правило таблицы: auth.uid == id,
    /// т.е. юзер может удалить только себя). App Store 5.1.1(v) требует
    /// возможность удаления аккаунта прямо из приложения.
    func deleteAccount(userId: String) async throws {
        let body: [String: Any] = ["where": "id == \"\(userId)\""]
        let _: TeenyEmpty = try await post(path: "/api/v1/table/users/delete", body: body)
    }

    // MARK: - Grammar

    func fetchAllGrammarLessons() async throws -> [GrammarLesson] {
        let resp: TeenyListResponse<RemoteGrammarLesson> = try await post(
            path: "/api/v1/table/grammar_lessons/list",
            body: ["limit": 200, "sort": "order_index"]
        )
        return resp.items.compactMap { remoteToGrammarLesson($0) }
    }

    // MARK: - Exam sessions

    func fetchAllExamSessions() async throws -> [ExamSession] {
        let resp: TeenyListResponse<RemoteExamSession> = try await post(
            path: "/api/v1/table/exam_sessions/list",
            body: ["limit": 100, "sort": "start_date"]
        )
        return resp.items.compactMap { remoteToExamSession($0) }
    }

    // MARK: - Generic POST

    /// Внутренний POST с автоматической подстановкой auth-токена и retry на 401.
    /// При 401 пытается обновить токен через AuthManager, повторяет запрос один раз.
    /// Если refresh не удался — signOut() и пробрасывает 401.
    private func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        try await postOnce(path: path, body: body, isRetry: false)
    }

    private func postOnce<T: Decodable>(path: String, body: [String: Any], isRetry: Bool) async throws -> T {
        guard let url = URL(string: VerbumConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth-токен пользователя приоритетнее статического contentReadToken.
        if let token = AuthManager.shared.currentAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if !VerbumConfig.contentReadToken.isEmpty {
            request.setValue("Bearer \(VerbumConfig.contentReadToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(0, message: nil)
        }

        if http.statusCode == 401 && !isRetry {
            // Пробуем рефреш токена и повторяем запрос один раз.
            do {
                try await AuthManager.shared.refresh()
                return try await postOnce(path: path, body: body, isRetry: true)
            } catch {
                AuthManager.shared.signOut()
                throw APIError.serverError(401, message: nil)
            }
        }

        if !(200...299).contains(http.statusCode) {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String }
            throw APIError.serverError(http.statusCode, message: message)
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

private func remoteToExamSession(_ r: RemoteExamSession) -> ExamSession? {
    let levels = (r.levels.data(using: .utf8))
        .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    let bundle = BundleExamSession(
        session_id: r.session_id, start_date: r.start_date, end_date: r.end_date, levels: levels
    )
    return ExamSessionParser.from(bundle)
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
