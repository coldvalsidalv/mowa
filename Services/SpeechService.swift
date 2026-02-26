import Foundation
import AVFoundation
import Combine

final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
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
            print("SpeechService: Failed to configure session: \(error)")
        }
    }
    
    private func observeInterruptions() {
        // Обработка входящих звонков и прерываний системы
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
    
    func speak(_ text: String, language: String = "pl-PL") {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "pl-PL")
        utterance.rate = 0.5
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
