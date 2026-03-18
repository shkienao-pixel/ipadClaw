import Foundation

/// 所有 OpenClaw Gateway 连接配置集中在此处
/// 切换服务器只需修改 baseURL 和 token
enum OpenClawConfig {
    static let baseURL    = "http://100.118.204.105:59690"
    static let token      = "vs2imf1RKkGbMgY4mtmfkQmmQKE5JBkC"   // ⚠️ 替换为真实 token
    static let agentID    = "friday"
    static let model      = "openclaw"

    /// 完整的 chat completions endpoint
    static var chatEndpoint: URL {
        URL(string: "\(baseURL)/v1/chat/completions")!
    }

    /// 请求超时秒数
    static let timeoutSeconds: TimeInterval = 30
}
