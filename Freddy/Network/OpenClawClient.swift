import Foundation

// MARK: - Client

final class OpenClawClient {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = OpenClawConfig.timeoutSeconds
        config.timeoutIntervalForResource = OpenClawConfig.timeoutSeconds
        session = URLSession(configuration: config)
    }

    /// 发送单条用户消息，返回 AI 回复文本（在调用方的并发上下文中执行）
    func send(userMessage: String) async throws -> String {
        let urlRequest = try buildURLRequest(userMessage: userMessage)
        let (data, response) = try await session.data(for: urlRequest)

        // 调试：打印原始响应
        if let raw = String(data: data, encoding: .utf8) {
            print("[OpenClaw] ← raw:\n\(raw)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenClawError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw OpenClawError.httpError(statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenClawResponse.self, from: data)
        guard let text = decoded.extractedText else {
            throw OpenClawError.noTextInResponse
        }
        return text
    }

    // MARK: Private

    private func buildURLRequest(userMessage: String) throws -> URLRequest {
        var req = URLRequest(url: OpenClawConfig.chatEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(OpenClawConfig.token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",               forHTTPHeaderField: "Content-Type")
        req.setValue(OpenClawConfig.agentID,           forHTTPHeaderField: "x-openclaw-agent-id")

        let body = OpenClawRequest(
            model: OpenClawConfig.model,
            messages: [.init(role: "user", content: userMessage)]
        )
        req.httpBody = try JSONEncoder().encode(body)
        print("[OpenClaw] → POST \(OpenClawConfig.chatEndpoint)  body: \(userMessage)")
        return req
    }
}

// MARK: - Errors

enum OpenClawError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case noTextInResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:         return "服务器返回无效响应"
        case .httpError(let code):     return "HTTP 错误 \(code)"
        case .noTextInResponse:        return "响应中未找到文本内容（见 Xcode Console 原始 JSON）"
        }
    }
}
