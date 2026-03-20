import Foundation

// MARK: - App State Machine

enum AppState: Equatable {
    case idle
    case listening
    case sending
    case speaking
    case error(String)

    var displayText: String {
        switch self {
        case .idle:               return "空闲，等待指令"
        case .listening:          return "聆听中..."
        case .sending:            return "发送中..."
        case .speaking:           return "播报中..."
        case .error(let msg):     return "错误：\(msg)"
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - OpenClaw Request

struct OpenClawRequest: Encodable {
    let model: String
    let messages: [ChatMessage]

    struct ChatMessage: Encodable {
        let role: String
        let content: String
    }
}

// MARK: - OpenClaw Response (OpenAI-compatible, robust parsing)

/// Top-level response wrapper.  All fields are optional to tolerate partial/non-standard responses.
struct OpenClawResponse: Decodable {
    let id: String?
    let object: String?
    let choices: [Choice]?
    let error: APIError?
    /// Some gateways return a bare `message` or `detail` at the top level
    let message: String?
    let detail: String?

    // MARK: Choice

    struct Choice: Decodable {
        let message: Message?
        let text: String?          // Some formats return `text` directly on the choice

        struct Message: Decodable {
            let role: String?
            /// content can be a plain string OR an array of rich content blocks
            let content: RawContent?
        }
    }

    // MARK: API Error

    struct APIError: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }
}

// MARK: - RawContent (string OR array of content blocks)

/// OpenAI spec allows `content` to be either a plain string or an array of typed blocks.
/// This enum decodes both transparently.
enum RawContent: Decodable {
    case text(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try plain string first
        if let str = try? container.decode(String.self) {
            self = .text(str)
            return
        }
        // Fall back to block array
        let blocks = try container.decode([ContentBlock].self)
        self = .blocks(blocks)
    }

    /// Flatten to a plain string regardless of which variant was received
    var stringValue: String? {
        switch self {
        case .text(let s):
            return s.isEmpty ? nil : s
        case .blocks(let bs):
            let joined = bs.compactMap { $0.text }.joined()
            return joined.isEmpty ? nil : joined
        }
    }
}

struct ContentBlock: Decodable {
    let type: String?
    let text: String?
}

// MARK: - OpenClaw Errors

enum OpenClawError: LocalizedError {
    case missingToken
    case invalidResponse
    case timeout
    case noNetwork
    case unauthorized          // 401
    case forbidden             // 403
    case serverError(Int)      // 5xx
    case httpError(Int)        // other non-2xx
    case decodingFailed(String)
    case noTextInResponse

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "未配置 token — 请在 Xcode scheme 环境变量 OPENCLAW_TOKEN 中填入真实密钥"
        case .invalidResponse:
            return "服务器返回无效响应（非 HTTP）"
        case .timeout:
            return "请求超时（已等待 \(Int(OpenClawConfig.timeoutSeconds)) 秒）"
        case .noNetwork:
            return "网络不可用，请检查 Wi-Fi / 蜂窝网络连接"
        case .unauthorized:
            return "服务器返回 401 — token 无效或已过期，请更新 OPENCLAW_TOKEN"
        case .forbidden:
            return "服务器返回 403 — 权限不足，请确认 agentID 和 token 正确"
        case .serverError(let code):
            return "服务器内部错误（HTTP \(code)），请稍后重试或检查后端日志"
        case .httpError(let code):
            return "HTTP 错误 \(code)"
        case .decodingFailed(let detail):
            return "返回格式无法解析：\(detail)（原始 JSON 已打印到 Console）"
        case .noTextInResponse:
            return "服务器已返回，但未解析到文本内容（原始 JSON 已打印到 Console）"
        }
    }
}
