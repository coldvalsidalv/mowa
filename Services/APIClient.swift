import Foundation

// MARK: - Transport DTOs

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

// MARK: - Error

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, message: String?)
}

// MARK: - APIClient (transport)

/// Сетевой слой. Здесь — только транспорт (generic POST с auth-токеном и retry на
/// 401). Доменные методы (vocabulary, fsrs, grammar, leaderboard, …) вынесены в
/// `APIClient+<Domain>.swift`, каждый со своими Remote-DTO.
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - Generic POST

    /// POST с автоматической подстановкой auth-токена и retry на 401.
    /// При 401 пытается обновить токен через AuthManager, повторяет запрос один раз.
    /// Если refresh не удался — signOut() и пробрасывает 401.
    ///
    /// Internal (не private): вызывается доменными расширениями в соседних файлах.
    func post<T: Decodable>(path: String, body: [String: Any], timeout: TimeInterval = 15) async throws -> T {
        try await postOnce(path: path, body: body, isRetry: false, timeout: timeout)
    }

    private func postOnce<T: Decodable>(path: String, body: [String: Any], isRetry: Bool, timeout: TimeInterval = 15) async throws -> T {
        guard let url = URL(string: VerbumConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
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
            } catch AuthError.network(let underlying) {
                // Network blip during refresh — session may still be valid; don't sign out.
                throw APIError.networkError(underlying)
            } catch {
                // Token invalid/exhausted/expired — session is dead.
                AuthManager.shared.signOut()
                throw APIError.serverError(401, message: nil)
            }
            // Retry outside the do/catch: its own network error must not trigger signOut.
            return try await postOnce(path: path, body: body, isRetry: true, timeout: timeout)
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
