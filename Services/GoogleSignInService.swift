import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - Errors

enum GoogleSignInError: LocalizedError {
    case cancelled
    case failed(String?)

    var errorDescription: String? {
        switch self {
        case .cancelled:          return nil // silent — user closed the sheet
        case .failed(let detail): return detail ?? L("error.google_signin")
        }
    }
}

// MARK: - GoogleSignInService

/// Google Sign-In without the GoogleSignIn SDK: ASWebAuthenticationSession +
/// OAuth 2.0 authorization-code flow with PKCE. iOS-type OAuth clients have no
/// client secret, so the whole exchange runs on-device. The result is Google's
/// id_token, which AuthManager.signIn(externalIdToken:) trades for a Verbum session.
final class GoogleSignInService: NSObject {
    static let shared = GoogleSignInService()
    private override init() {}

    // Keeps the session alive while the sheet is on screen.
    private var activeSession: ASWebAuthenticationSession?

    /// Runs the full flow and returns Google's id_token.
    /// Throws GoogleSignInError.cancelled when the user dismisses the sheet.
    func signIn() async throws -> String {
        guard VerbumConfig.isGoogleSignInConfigured else {
            throw GoogleSignInError.failed(nil)
        }

        let verifier = Self.randomURLSafeString(bytes: 48)
        let state = Self.randomURLSafeString(bytes: 24)
        let scheme = VerbumConfig.googleReversedClientID
        let redirectURI = scheme + ":/oauth2redirect"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: VerbumConfig.googleIOSClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        let callbackURL = try await authenticate(url: components.url!, callbackScheme: scheme)

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        guard items?.first(where: { $0.name == "state" })?.value == state,
              let code = items?.first(where: { $0.name == "code" })?.value else {
            throw GoogleSignInError.failed(nil)
        }

        return try await exchangeCode(code, verifier: verifier, redirectURI: redirectURI)
    }

    // MARK: - Web auth session

    private func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    let isCancel = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: isCancel
                        ? GoogleSignInError.cancelled
                        : GoogleSignInError.failed(error.localizedDescription))
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: GoogleSignInError.failed(nil))
                }
            }
            session.presentationContextProvider = self
            activeSession = session
            if !session.start() {
                continuation.resume(throwing: GoogleSignInError.failed(nil))
            }
        }
    }

    // MARK: - Code → id_token exchange

    private struct TokenResponse: Decodable {
        let id_token: String
    }

    private func exchangeCode(_ code: String, verifier: String, redirectURI: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: VerbumConfig.googleIOSClientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        request.httpBody = body.query?.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GoogleSignInError.failed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            verbumLog("❌ GoogleSignIn: token exchange failed — \(String(data: data, encoding: .utf8) ?? "?")")
            throw GoogleSignInError.failed(nil)
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data).id_token
        } catch {
            throw GoogleSignInError.failed(nil)
        }
    }

    // MARK: - PKCE helpers

    private static func randomURLSafeString(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

extension GoogleSignInService: @preconcurrency ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
