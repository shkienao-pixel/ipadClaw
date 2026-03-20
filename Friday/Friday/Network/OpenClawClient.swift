import Foundation

// MARK: - Client

final class OpenClawClient {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = OpenClawConfig.timeoutSeconds
        cfg.timeoutIntervalForResource = OpenClawConfig.timeoutSeconds * 2   // extra headroom
        session = URLSession(configuration: cfg)
    }

    // MARK: - Public API

    /// Send a single user message and return the assistant's reply text.
    func send(userMessage: String) async throws -> String {
        // Guard: token must be configured before we even build the request
        try OpenClawConfig.validateToken()

        let urlRequest = try buildURLRequest(userMessage: userMessage)
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }

        // Log raw response body
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 data, \(data.count) bytes>"
        print("[OpenClaw] ← raw response:\n\(rawBody)\n")

        // Validate HTTP status
        guard let http = response as? HTTPURLResponse else {
            throw OpenClawError.invalidResponse
        }
        print("[OpenClaw] ← HTTP \(http.statusCode)")

        switch http.statusCode {
        case 200...299:
            break   // proceed to parse
        case 401:
            throw OpenClawError.unauthorized
        case 403:
            throw OpenClawError.forbidden
        case 500...599:
            throw OpenClawError.serverError(http.statusCode)
        default:
            throw OpenClawError.httpError(http.statusCode)
        }

        // Parse response using the robust helper
        return try extractAssistantText(from: data)
    }

    // MARK: - Request Builder

    private func buildURLRequest(userMessage: String) throws -> URLRequest {
        var req = URLRequest(url: OpenClawConfig.chatEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json",                forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(OpenClawConfig.token)", forHTTPHeaderField: "Authorization")
        req.setValue(OpenClawConfig.agentID,            forHTTPHeaderField: "x-openclaw-agent-id")

        let body = OpenClawRequest(
            model: OpenClawConfig.model,
            messages: [.init(role: "user", content: userMessage)]
        )
        req.httpBody = try JSONEncoder().encode(body)

        // Full request log (Authorization value is masked)
        let bodyPreview = String(data: req.httpBody!, encoding: .utf8) ?? "<encode error>"
        print("""
        [OpenClaw] → POST \(OpenClawConfig.chatEndpoint)
          Headers:
            Content-Type: application/json
            Authorization: \(maskedAuth(OpenClawConfig.token))
            x-openclaw-agent-id: \(OpenClawConfig.agentID)
          Body: \(bodyPreview)
        """)

        return req
    }

    // MARK: - Robust Response Parser

    /// Extract the assistant's text from a chat-completions response.
    /// Handles: plain string content, content-block arrays, bare message/detail fields.
    /// On failure, dumps raw JSON to console and throws a descriptive error.
    func extractAssistantText(from data: Data) throws -> String {

        // ── Strategy 1: full Codable decode ─────────────────────────────────
        if let decoded = try? JSONDecoder().decode(OpenClawResponse.self, from: data) {

            // 1a. choices[0].message.content  (string or block array)
            if let content = decoded.choices?.first?.message?.content?.stringValue,
               !content.isEmpty {
                return content
            }

            // 1b. choices[0].text  (legacy / completions style)
            if let text = decoded.choices?.first?.text, !text.isEmpty {
                return text
            }

            // 1c. Top-level error from server
            if let errMsg = decoded.error?.message, !errMsg.isEmpty {
                return "服务端错误：\(errMsg)"
            }

            // 1d. Top-level message / detail fields (some gateways)
            if let msg = decoded.message, !msg.isEmpty {
                return msg
            }
            if let detail = decoded.detail, !detail.isEmpty {
                return detail
            }
        }

        // ── Strategy 2: raw JSON dictionary fallback ─────────────────────────
        // Walk the JSON manually to catch any non-standard nesting
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("[OpenClaw] ⚠ Codable decode missed content — scanning raw JSON: \(json)")

            // Direct string fields
            for key in ["message", "detail", "text", "content", "response", "reply"] {
                if let s = json[key] as? String, !s.isEmpty { return s }
            }

            // choices[0].message.content as string
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first {
                if let msg = first["message"] as? [String: Any],
                   let content = msg["content"] as? String,
                   !content.isEmpty {
                    return content
                }
                if let text = first["text"] as? String, !text.isEmpty {
                    return text
                }
            }
        }

        // ── Nothing found ────────────────────────────────────────────────────
        let rawBody = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[OpenClaw] ✗ No text found in response. Raw body:\n\(rawBody)")
        throw OpenClawError.noTextInResponse
    }

    // MARK: - Helpers

    /// Map URLError to a more descriptive OpenClawError
    private func mapURLError(_ e: URLError) -> OpenClawError {
        switch e.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .noNetwork
        default:
            return .invalidResponse
        }
    }

    /// Mask an Authorization token for safe logging:
    /// e.g. "vs2i...JBKC" (show first 4 and last 4 characters only)
    private func maskedAuth(_ token: String) -> String {
        guard token.count > 8 else { return "Bearer ***" }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        return "Bearer \(prefix)...\(suffix)"
    }
}
