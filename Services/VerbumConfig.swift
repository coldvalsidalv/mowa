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
