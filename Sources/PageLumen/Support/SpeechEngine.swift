import AVFoundation
import Foundation

@MainActor
final class SpeechEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.voice = selectedVoice()
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        let defaults = UserDefaults.standard
        let usePersonalVoice = defaults.object(forKey: "usePersonalVoice") as? Bool ?? true
        if usePersonalVoice,
           let personalVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.voiceTraits.contains(.isPersonalVoice) }) {
            return personalVoice
        }
        if let selectedID = defaults.string(forKey: "speechVoiceIdentifier"),
           let selectedVoice = AVSpeechSynthesisVoice(identifier: selectedID),
           !selectedVoice.voiceTraits.contains(.isPersonalVoice) {
            return selectedVoice
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}
