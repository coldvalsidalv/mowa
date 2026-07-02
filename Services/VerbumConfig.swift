import Foundation

enum VerbumConfig {
    /// Backend base URL. Change it only here when deploying to prod.
    #if DEBUG
    // On the simulator 127.0.0.1 works (loopback on the Mac).
    // To test on a physical device: bring up a cloudflared/ngrok tunnel and
    // temporarily put the https URL on the second line. Do NOT commit the tunnel URL —
    // it's ephemeral. See CLAUDE.md → "Тестирование на физическом девайсе".
    static let baseURL = "http://127.0.0.1:8787" // codeql[swift/cleartext-transmission]
    // static let baseURL = "https://<your-tunnel>.trycloudflare.com"
    #else
    static let baseURL = "https://verbum-backend.verbum-mowa.workers.dev"
    #endif

    /// Public token for reading content (vocabulary, grammar).
    /// Not a secret — the content is publicly accessible per Teenybase rules.
    static let contentReadToken = ""

    // MARK: - Google Sign-In

    /// iOS OAuth client ID from Google Cloud Console (Credentials → OAuth client, type iOS).
    /// Not a secret — it is visible in the binary anyway. While empty, the Google button
    /// is hidden in AuthView. The same ID must be set as GOOGLE_IOS_CLIENT_ID on the backend.
    static let googleIOSClientID = "690760115922-ps0iul156lu6b3aer0uabhma01a0k8a7.apps.googleusercontent.com"

    /// Redirect scheme for the OAuth callback: reversed client ID
    /// ("123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc").
    static var googleReversedClientID: String {
        googleIOSClientID.split(separator: ".").reversed().joined(separator: ".")
    }

    static var isGoogleSignInConfigured: Bool { !googleIOSClientID.isEmpty }

    // MARK: - FSRS

    /// Target retention level (0.80–0.95). Higher means more frequent reviews.
    /// 0.90 is the common baseline (Anki/RemNote).
    static let fsrsDesiredRetention: Double = 0.90

    /// stability ≥ this value (days) → unlock cloze mode.
    static let fsrsClozeUnlockStability: Double = 7.0

    /// Max repeats of a single card per session on an .again answer.
    /// Prevents an endless session on a bad day.
    static let fsrsMaxAgainRepeatsPerSession: Int = 3
}
