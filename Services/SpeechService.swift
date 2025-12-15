import AVFoundation

class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(_ text: String, language: String = "pl-PL") {
        // Останавливаем, если уже что-то говорит
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5 // Скорость речи (0.5 - нормальная)
        utterance.pitchMultiplier = 1.0
        
        synthesizer.speak(utterance)
    }
}
