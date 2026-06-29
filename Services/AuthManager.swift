import Foundation
import Combine

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailInUse
    case validation(String)
    case network(Error)
    case server(Int, String?)
    case noRefreshToken
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:     return "Неверный email или пароль"
        case .emailInUse:             return "Этот email уже зарегистрирован"
        case .validation(let msg):    return msg
        case .network:                return "Нет соединения с сервером"
        case .server(let code, let m): return m ?? "Ошибка сервера (\(code))"
        case .noRefreshToken:         return "Сессия истекла, войди заново"
        case .decoding:               return "Не получилось прочитать ответ сервера"
        }
    }
}

// MARK: - DTOs (соответствуют teenybase /auth/*)

private struct SignUpBody: Encodable {
    let username: String
    let email: String
    let password: String
    let name: String
}

private struct LoginBody: Encodable {
    let identity: String
    let password: String
}

private struct RefreshBody: Encodable {
    let refresh_token: String
}

private struct AuthResponse: Decodable {
    let token: String
    let refresh_token: String
    let record: UserRecord

    struct UserRecord: Decodable {
        let id: String
        let email: String?
    }
}

// MARK: - AuthManager

/// Управление JWT-сессией. Single source of truth для статуса авторизации.
/// `isAuthenticated` — true когда в Keychain лежит валидный access token.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var currentEmail: String?
    @Published private(set) var lastError: String?

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = JSONDecoder()
    private let encoder: JSONEncoder = JSONEncoder()

    // Single in-flight refresh task; concurrent callers await it instead of starting their own.
    private var refreshTask: Task<Void, Error>?

    private init() {
        let token = KeychainHelper.load(KeychainKeys.accessToken)
        self.isAuthenticated = (token != nil)
        self.currentEmail = KeychainHelper.load(KeychainKeys.userEmail)
    }

    // MARK: - Public API

    func signUp(email: String, password: String, name: String?) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try validateEmail(trimmed)
        try validatePassword(password)

        // teenybase требует username по regex ^[a-zA-Z][a-zA-Z0-9_]*$.
        // Email не подходит из-за @ и точек. Генерируем случайный — он внутренний,
        // юзер его не видит. Email — единственный публичный identity.
        let body = SignUpBody(
            username: Self.generateUsername(),
            email: trimmed,
            password: password,
            name: name?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? name!
                : trimmed.split(separator: "@").first.map(String.init) ?? trimmed
        )

        let resp: AuthResponse = try await postAuth(path: "sign-up", body: body)
        storeSession(resp)
    }

    private static func generateUsername() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let tail = (0..<15).map { _ in alphabet.randomElement()! }
        return "u" + String(tail) // 16 символов, начинается с буквы
    }

    func signIn(email: String, password: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try validateEmail(trimmed)

        let body = LoginBody(identity: trimmed, password: password)
        let resp: AuthResponse = try await postAuth(path: "login-password", body: body)
        storeSession(resp)
    }

    func signOut() {
        KeychainHelper.delete(KeychainKeys.accessToken)
        KeychainHelper.delete(KeychainKeys.refreshToken)
        KeychainHelper.delete(KeychainKeys.userEmail)
        KeychainHelper.delete(KeychainKeys.userId)
        isAuthenticated = false
        currentEmail = nil
        // Сбросить FSRS-параметры — они привязаны к юзеру.
        FSRSParamStore.shared.reset()
    }

    /// Используется APIClient'ом для подстановки в Authorization-заголовок.
    /// nonisolated, потому что Keychain thread-safe и нам не нужен хоп на главный actor.
    nonisolated func currentAccessToken() -> String? {
        KeychainHelper.load(KeychainKeys.accessToken)
    }

    /// Освежает токен по refresh_token. Бросает .noRefreshToken если refresh отсутствует.
    /// При успехе — обновляет токены в Keychain. При неудаче — НЕ делает signOut автоматически
    /// (это решение принимает caller).
    func refresh() async throws {
        // Single-flight: if a refresh is already running, await it instead of starting a second.
        if let existing = refreshTask {
            try await existing.value
            return
        }
        let task = Task {
            defer { self.refreshTask = nil }
            try await self.performRefresh()
        }
        refreshTask = task
        try await task.value
    }

    private func performRefresh() async throws {
        guard let refreshTok = KeychainHelper.load(KeychainKeys.refreshToken) else {
            throw AuthError.noRefreshToken
        }

        let body = RefreshBody(refresh_token: refreshTok)
        let resp: AuthResponse = try await postAuth(path: "refresh-token", body: body,
                                                    authHeader: KeychainHelper.load(KeychainKeys.accessToken))
        storeSession(resp)
    }

    // MARK: - Private

    private func storeSession(_ resp: AuthResponse) {
        KeychainHelper.save(resp.token, for: KeychainKeys.accessToken)
        KeychainHelper.save(resp.refresh_token, for: KeychainKeys.refreshToken)
        KeychainHelper.save(resp.record.id, for: KeychainKeys.userId)
        if let email = resp.record.email {
            KeychainHelper.save(email, for: KeychainKeys.userEmail)
            currentEmail = email
        }
        isAuthenticated = true
        lastError = nil
    }

    private func postAuth<T: Encodable, R: Decodable>(path: String, body: T,
                                                       authHeader: String? = nil) async throws -> R {
        guard let url = URL(string: VerbumConfig.baseURL + "/api/v1/table/users/auth/" + path) else {
            throw AuthError.network(URLError(.badURL))
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authHeader {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? encoder.encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network(URLError(.badServerResponse))
        }

        if (200...299).contains(http.statusCode) {
            do {
                return try decoder.decode(R.self, from: data)
            } catch {
                throw AuthError.decoding(error)
            }
        }

        // Парсим серверную ошибку
        let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?
            .flatMap { dict -> String? in
                if let m = dict["message"] as? String { return m }
                if let e = dict["error"] as? String { return e }
                return nil
            }

        switch (http.statusCode, path) {
        case (401, "login-password"), (400, "login-password"):
            throw AuthError.invalidCredentials
        case (409, "sign-up"):
            throw AuthError.emailInUse
        case (400, "sign-up") where serverMessage?.lowercased().contains("email") == true:
            throw AuthError.emailInUse
        default:
            throw AuthError.server(http.statusCode, serverMessage)
        }
    }

    private func validateEmail(_ email: String) throws {
        // Минимальная проверка: есть @ и точка после @.
        let parts = email.split(separator: "@")
        guard parts.count == 2, parts[1].contains(".") else {
            throw AuthError.validation("Неверный формат email")
        }
    }

    private func validatePassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw AuthError.validation("Пароль минимум 8 символов")
        }
    }
}
