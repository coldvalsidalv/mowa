import Foundation
import AVFoundation
import Combine

final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var fetchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    @Published var isSpeaking = false

    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        observeInterruptions()
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            verbumLog("SpeechService: Failed to configure session: \(error)")
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

                if type == .began {
                    self?.stop()
                } else if type == .ended {
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            try? AVAudioSession.sharedInstance().setActive(true)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Speaks a vocabulary word using backend-cached ElevenLabs audio when available.
    /// Falls back to AVSpeechSynthesizer if the download fails or audio not generated yet.
    func speak(_ word: VocabItem) {
        let polish = word.polish

        fetchTask?.cancel()
        fetchTask = nil

        let cacheURL = ttsCacheURL(for: polish)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            playAudio(url: cacheURL)
            return
        }

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await self.downloadTTS(polish: polish)
                guard !Task.isCancelled else { return }
                try data.write(to: cacheURL)
                await MainActor.run { self.playAudio(url: cacheURL) }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.speakWithSynthesizer(polish) }
            }
        }
    }

    /// Speaks arbitrary text via AVSpeechSynthesizer (examples, inflections, etc.)
    func speak(_ text: String, language: String = "pl-PL") {
        speakWithSynthesizer(text, language: language)
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    // MARK: - Private

    private func speakWithSynthesizer(_ text: String, language: String = "pl-PL") {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = bestVoice(for: language)
        utterance.rate = 0.45

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.speak(utterance)
    }

    private func playAudio(url: URL) {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isSpeaking = true
        } catch {
            verbumLog("SpeechService: Failed to play \(url.lastPathComponent): \(error)")
        }
    }

    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        let ranked = voices.sorted { $0.quality.rawValue > $1.quality.rawValue }
        return ranked.first ?? AVSpeechSynthesisVoice(language: language)
    }

    private func downloadTTS(polish: String) async throws -> Data {
        let encoded = polish.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? polish
        let url = URL(string: "\(VerbumConfig.baseURL)/api/tts/\(encoded)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func ttsCacheURL(for polish: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("verbum-tts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = polish.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? polish
        return dir.appendingPathComponent("\(safe).mp3")
    }
}

// MARK: - Delegates

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

extension SpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
