import AVFoundation
import Foundation
import Observation
import Speech

/// Turns your voice into text, on the iPhone (nothing is sent to a server
/// when on-device recognition is available, which it is on iPhone 17).
@MainActor
@Observable
final class SpeechService {
    enum SpeechError: LocalizedError {
        case notAllowed
        case unavailable

        var errorDescription: String? {
            switch self {
            case .notAllowed: "Allow Microphone and Speech Recognition for Climb High in Settings to use voice."
            case .unavailable: "Speech recognition isn't available right now."
            }
        }
    }

    private(set) var transcript = ""
    private(set) var isListening = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermission() async -> Bool {
        guard await Self.requestSpeechAuthorization() else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() async throws {
        guard !isListening else { return }
        guard await requestPermission() else { throw SpeechError.notAllowed }
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }

        transcript = ""
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = true
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: format, block: Self.tapBlock(feeding: request))
        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler { [weak self] text, isDone in
            guard let self else { return }
            if let text { self.transcript = text }
            if isDone { self.finish() }
        })
    }

    /// Stops listening and returns what was heard.
    @discardableResult
    func stop() -> String {
        request?.endAudio()
        finish()
        return transcript
    }

    // MARK: Callbacks that run off the main thread
    //
    // Speech and audio call these on background threads, so they're built in
    // `nonisolated` functions and hop back to the main actor explicitly.

    nonisolated private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    nonisolated private static func tapBlock(feeding request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    nonisolated private static func resultHandler(
        _ update: @escaping @MainActor (String?, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isDone = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in update(text, isDone) }
        }
    }

    private func finish() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.finish()
        task = nil
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
