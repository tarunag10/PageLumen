import AVFoundation
import Foundation

@MainActor
public final class AudioExportService {
    private var activeSynthesizer: AVSpeechSynthesizer?
    private var activeCollector: AudioBufferCollector?

    public init() {}

    public func export(
        text: String,
        to url: URL,
        language: String = "en-US",
        voiceIdentifier: String? = nil
    ) async throws {
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
        utterance.voice = voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let collector = AudioBufferCollector(file: file, continuation: continuation)
            activeSynthesizer = synthesizer
            activeCollector = collector
            synthesizer.write(utterance, toBufferCallback: { buffer in
                if let pcm = buffer as? AVAudioPCMBuffer {
                    if pcm.frameLength == 0 {
                        collector.finish()
                    } else {
                        collector.write(pcm)
                    }
                } else {
                    collector.finish()
                }
            })
        }
        activeSynthesizer = nil
        activeCollector = nil
    }

    /// Stops the active synthesis and resolves the export operation as
    /// cancelled. Calling this when no export is running is a safe no-op.
    public func cancel() {
        activeSynthesizer?.stopSpeaking(at: .immediate)
        activeCollector?.finish(with: AudioExportError.cancelled)
        activeSynthesizer = nil
        activeCollector = nil
    }

    private func makeAudioFormat() -> AudioExportFormat {
        AudioExportFormat(sampleRate: 22_050, channelCount: 1)
    }
}

public enum AudioExportError: LocalizedError {
    case emptyText
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "There is no readable text to convert into audio."
        case .cancelled:
            return "Audio export was cancelled."
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

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        do {
            try file.write(from: buffer)
        } catch {
            finished = true
            lock.unlock()
            continuation.resume(throwing: error)
            return
        }
        lock.unlock()
    }
}
