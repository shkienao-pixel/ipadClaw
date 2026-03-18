import Foundation
import Combine
import Speech
import AVFoundation

final class SpeechRecognizer: ObservableObject {

    @Published private(set) var partialText: String = ""
    @Published private(set) var isAuthorized: Bool  = false

    var onFinalResult: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recogRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recogTask:    SFSpeechRecognitionTask?
    private let audioEngine  = AVAudioEngine()
    private var tapInstalled = false   // 防止 removeTap 被多次调用

    // MARK: - Auth

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                let ok = (status == .authorized)
                self?.isAuthorized = ok
                print("[Speech] auth status: \(status.rawValue)  authorized=\(ok)")
                if !ok {
                    self?.onError?("语音识别权限未授权，请前往设置开启")
                }
            }
        }
    }

    // MARK: - Start

    func startListening() {
        guard !audioEngine.isRunning else {
            print("[Speech] already running, skip")
            return
        }

        // 1. 权限
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            notify(error: "语音识别未授权")
            return
        }

        // 2. 引擎可用性（需要网络；zh-CN 没有离线模型）
        guard let recognizer, recognizer.isAvailable else {
            notify(error: "识别引擎不可用，请检查网络连接")
            return
        }

        // 3. 音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            notify(error: "音频会话错误：\(error.localizedDescription)")
            return
        }

        // 4. 识别请求
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recogRequest = request

        // 5. 识别任务
        recogTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }

                // 先处理有效结果
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.partialText = text
                    if result.isFinal {
                        print("[Speech] final result: \(text)")
                        self.cleanupEngine()
                        self.onFinalResult?(text)
                        return   // ← 拿到 final 就 return，不再走 error 分支
                    }
                }

                // 再处理错误
                if let error {
                    let nsError = error as NSError
                    print("[Speech] error domain=\(nsError.domain) code=\(nsError.code): \(error.localizedDescription)")

                    if nsError.code == 1110 {
                        // 静音超时：把已识别的内容当最终结果
                        let text = self.partialText
                        self.cleanupEngine()
                        if !text.isEmpty {
                            self.onFinalResult?(text)
                        }
                        // text 为空说明用户没说话，静默恢复 idle 即可
                    } else {
                        self.cleanupEngine()
                        self.onError?("识别错误 (\(nsError.code))：\(error.localizedDescription)")
                    }
                }
            }
        }

        // 6. 挂载音频 tap（捕获局部 request 避免在后台线程访问 self）
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("[Speech] installing tap, format: sampleRate=\(format.sampleRate) ch=\(format.channelCount)")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        // 7. 启动引擎
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("[Speech] engine started")
        } catch {
            removeTapIfNeeded()
            notify(error: "音频引擎启动失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Stop（外部主动调用）

    func stopListening() {
        cleanupEngine()
    }

    // MARK: - Private

    /// 统一清理入口，可安全多次调用
    private func cleanupEngine() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        removeTapIfNeeded()
        recogRequest?.endAudio()
        recogRequest = nil
        recogTask?.cancel()
        recogTask = nil
        DispatchQueue.main.async { [weak self] in self?.partialText = "" }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("[Speech] engine stopped")
    }

    private func removeTapIfNeeded() {
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func notify(error msg: String) {
        DispatchQueue.main.async { [weak self] in self?.onError?(msg) }
    }
}
