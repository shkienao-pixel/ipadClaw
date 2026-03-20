import Foundation

/// All OpenClaw Gateway connection settings are centralized here.
///
/// SECURITY — how to supply the real token (checked in priority order):
///   1. Xcode scheme env var:  OPENCLAW_TOKEN=xxx
///      (Edit Scheme → Run → Arguments → Environment Variables — never committed)
///   2. Info.plist key:        OpenClawToken  (fill in locally, keep out of git)
///   3. If neither is set, the app shows "Missing OpenClaw token" at runtime.
///
/// NEVER hardcode the real token in this file.
enum OpenClawConfig {

    static let baseURL = "http://76.13.216.86:59690"
    static let agentID = "friday"

    /// Model name sent to the server.
    /// Default: "x-openclaw".  Change here if the server expects a different value.
    static let model = "x-openclaw"   // previous value was "openclaw"

    /// Chat completions endpoint
    static var chatEndpoint: URL {
        URL(string: "\(baseURL)/v1/chat/completions")!
    }

    /// Network timeout in seconds (raised from 30 → 90 for slow LLM responses)
    static let timeoutSeconds: TimeInterval = 90

    // MARK: - Token (never hard-code real value here)

    /// Returns the bearer token, or empty string if unconfigured.
    /// Call `validateToken()` before making requests.
    static var token: String {
        // Priority 1: Xcode scheme env var — easiest for local debugging, never persisted to git
        if let env = ProcessInfo.processInfo.environment["OPENCLAW_TOKEN"],
           !env.isEmpty {
            return env
        }
        // Priority 2: Info.plist key "OpenClawToken" — fill in locally after cloning
        if let plist = Bundle.main.object(forInfoDictionaryKey: "OpenClawToken") as? String,
           !plist.isEmpty,
           plist != "REPLACE_WITH_YOUR_TOKEN" {
            return plist
        }
        // Not configured
        return ""
    }

    /// Throws `OpenClawError.missingToken` if the token has not been set.
    static func validateToken() throws {
        if token.isEmpty {
            throw OpenClawError.missingToken
        }
    }
}
