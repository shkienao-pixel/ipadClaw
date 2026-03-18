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
        case .idle:         return "空闲，等待指令"
        case .listening:    return "聆听中..."
        case .sending:      return "发送中..."
        case .speaking:     return "播报中..."
        case .error(let msg): return "错误：\(msg)"
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

// MARK: - OpenClaw Response (OpenAI-compatible)

struct OpenClawResponse: Decodable {
    let id: String?
    let object: String?
    let choices: [Choice]?
    let error: APIError?

    struct Choice: Decodable {
        let message: Message?
        let text: String?          // 部分格式直接返回 text

        struct Message: Decodable {
            let role: String?
            let content: String?
        }
    }

    struct APIError: Decodable {
        let message: String?
    }

    /// 安全提取回复文本，兼容多种 OpenAI-compatible 结构
    var extractedText: String? {
        // 优先取 choices[0].message.content
        if let content = choices?.first?.message?.content, !content.isEmpty {
            return content
        }
        // 备用：choices[0].text
        if let text = choices?.first?.text, !text.isEmpty {
            return text
        }
        // 服务端返回错误
        if let errMsg = error?.message {
            return "服务端错误：\(errMsg)"
        }
        return nil
    }
}
