import AVFoundation
import Foundation

@MainActor
public final class AudioExportService {
    public init() {}

    public func export(text: String, to url: URL) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AudioExportError.emptyText
        }

        let directory = url.deletingPathExtension().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let format = makeAudioFormat()
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let collector = AudioBufferCollector(file: file, continuation: continuation)
            synthesizer.write(utterance, toBufferCallback: { buffer in
                if let pcm = buffer as? AVAudioPCMBuffer {
                    do {
                        try collector.file.write(from: pcm)
                    } catch {
                        collector.finish(with: error)
                    }
                    return
                }
                if buffer == nil {
                    collector.finish()
                }
            })
        }
    }

    private func makeAudioFormat() -> AudioExportFormat {
        AudioExportFormat(sampleRate: 22_050, channelCount: 1)
    }
}

public enum AudioExportError: LocalizedError {
    case emptyText

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "There is no readable text to convert into audio."
        }
    }
}

struct AudioExportFormat {
    let sampleRate: Double
    let channelCount: AVAudioChannelCount

    var commonFormat: AVAudioCommonFormat {
        .pcmFormatFloat32
    }

    var isInterleaved: Bool {
        false
    }

    var settings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
    }
}

private final class AudioBufferCollector: @unchecked Sendable {
    let file: AVAudioFile
    private let continuation: CheckedContinuation<Void, Error>
    private let lock = NSLock()
    private var finished = false

    init(file: AVAudioFile, continuation: CheckedContinuation<Void, Error>) {
        self.file = file
        self.continuation = continuation
    }

    func finish() {
        finish(with: nil)
    }

    func finish(with error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
