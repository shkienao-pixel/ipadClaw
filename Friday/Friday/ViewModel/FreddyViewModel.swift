import Foundation
import Combine

@MainActor
final class FreddyViewModel: ObservableObject {

    // MARK: - Published

    @Published var appState:        AppState = .idle
    @Published var partialText:     String   = ""
    @Published var lastUserMessage: String   = ""
    @Published var lastAIReply:     String   = ""

    // MARK: - Dependencies

    private let speech  = SpeechRecognizer()
    private let tts     = TTSManager()
    private let client  = OpenClawClient()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // 把 SpeechRecognizer.partialText 桥接过来
        speech.$partialText
            .receive(on: DispatchQueue.main)
            .assign(to: &$partialText)

        // 识别完成 → 发送
        // 回调在主线程（SpeechRecognizer 保证），Task + MainActor.run 消除隔离警告
        speech.onFinalResult = { [weak self] text in
            Task { [weak self] in
                await MainActor.run { self?.send(text: text) }
            }
        }

        // 识别出错
        speech.onError = { [weak self] msg in
            Task { [weak self] in
                await MainActor.run { self?.appState = .error(msg) }
            }
        }

        // TTS 播完 → idle
        // TTSManager 是 @MainActor，onFinished 从 @MainActor 上下文调用，直接赋值安全
        tts.onFinished = { [weak self] in
            Task { [weak self] in
                await MainActor.run { self?.appState = .idle }
            }
        }

        speech.requestAuthorization()
    }

    // MARK: - Public

    func toggleListening() {
        switch appState {
        case .listening:      stopListening()
        case .idle, .error:   startListening()
        default:              break
        }
    }

    func sendTestMessage() {
        send(text: "hello，请用中文介绍一下你自己")
    }

    // MARK: - Private

    private func startListening() {
        tts.stop()
        appState    = .listening
        partialText = ""
        speech.startListening()
    }

    private func stopListening() {
        speech.stopListening()
        appState = .idle
    }

    private func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastUserMessage = trimmed
        appState        = .sending

        Task {
            do {
                let reply = try await client.send(userMessage: trimmed)
                // Task 继承 @MainActor 上下文，直接更新 UI
                lastAIReply = reply
                appState    = .speaking
                tts.speak(reply)
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription
                       ?? error.localizedDescription
                appState    = .error(msg)
                lastAIReply = "（请求失败）"
            }
        }
    }
}
