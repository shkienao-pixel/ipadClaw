import Foundation
import Speech
import AVFoundation

/// 封装 SFSpeechRecognizer。
/// 注意：不标 @MainActor，音频回调在后台线程；
/// 所有 @Published 更新和回调统一通过 DispatchQueue.main.async 切回主线程。
final class SpeechRecognizer: ObservableObject {

    // MARK: - Published

    @Published private(set) var partialText: String = ""
    @Published private(set) var isAuthorized: Bool  = false

    // MARK: - Callbacks（在主线程调用）

    var onFinalResult: ((String) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - Private

    private let recognizer   = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recogRequest : SFSpeechAudioBufferRecognitionRequest?
    private var recogTask    : SFSpeechRecognitionTask?
    private let audioEngine  = AVAudioEngine()

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = (status == .authorized)
                if status != .authorized {
                    self?.onError?("语音识别权限未授权，请在设置中开启")
                }
            }
        }
    }

    // MARK: - Start

    func startListening() {
        guard !audioEngine.isRunning else { return }

        // 配置音频会话
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("音频会话错误：\(error.localizedDescription)")
            }
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recogRequest = request

        // 识别回调（在任意线程）→ 切回主线程
        recogTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.partialText = text
                    if result.isFinal {
                        self.stopListening()
                        self.onFinalResult?(text)
                    }
                }
                if let error {
                    let nsError = error as NSError
                    // code 1110 = 静音超时，是正常结束，不报错
                    if nsError.code != 1110 {
                        self.stopListening()
                        self.onError?("识别错误：\(error.localizedDescription)")
                    }
                }
            }
        }

        // 挂载音频输入。
        // 关键：把 request 捕获为局部常量，避免在后台线程访问 self 的 @Published 属性。
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("音频引擎启动失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Stop

    func stopListening() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recogRequest?.endAudio()
        recogRequest = nil
        recogTask?.cancel()
        recogTask = nil
        DispatchQueue.main.async { [weak self] in
            self?.partialText = ""
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
