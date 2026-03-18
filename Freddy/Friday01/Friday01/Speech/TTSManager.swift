import AVFoundation

@MainActor
final class TTSManager: NSObject, ObservableObject {

    @Published private(set) var isSpeaking = false

    var onFinished: (() -> Void)?

    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice  = AVSpeechSynthesisVoice(language: "zh-CN")
                        ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0

        isSpeaking = true
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    // 私有 @MainActor 辅助方法，由 nonisolated delegate 通过 Task 调用
    private func didFinish() {
        isSpeaking = false
        onFinished?()
    }

    private func didCancel() {
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSManager: AVSpeechSynthesizerDelegate {

    // delegate 回调在任意线程，标 nonisolated；通过 Task + await 跳回 @MainActor
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { [weak self] in await self?.didFinish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { [weak self] in await self?.didCancel() }
    }
}
