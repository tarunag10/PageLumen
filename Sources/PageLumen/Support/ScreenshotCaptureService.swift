import AppKit
import CoreGraphics
import Foundation

enum ScreenshotCaptureMode {
    case selectedRegion
    case window

    var filePrefix: String {
        switch self {
        case .selectedRegion:
            return "PageLumen-Selection"
        case .window:
            return "PageLumen-Window"
        }
    }
}

enum ScreenshotCaptureError: LocalizedError {
    case commandFailed(Int32)
    case missingOutput

    var errorDescription: String? {
        switch self {
        case .commandFailed(let status):
            return "Screenshot capture failed with status \(status)."
        case .missingOutput:
            return "No screenshot was captured."
        }
    }
}

struct ScreenshotCaptureService {
    func capture(mode: ScreenshotCaptureMode) async throws -> URL {
        // Prompt the system for screen-capture access on first use. The
        // `screencapture` binary requires this TCC permission; calling the
        // accessor surfaces the standard system prompt the first time the
        // user invokes capture. Subsequent invocations are no-ops if access
        // has already been granted.
        _ = CGRequestScreenCaptureAccess()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(mode.filePrefix)-\(UUID().uuidString)")
            .appendingPathExtension("png")

        return try await legacyCapture(mode: mode, outputURL: url)
    }

    private func legacyCapture(mode: ScreenshotCaptureMode, outputURL: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments(for: mode, output: outputURL)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ScreenshotCaptureError.commandFailed(process.terminationStatus)
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw ScreenshotCaptureError.missingOutput
        }

        return outputURL
    }

    private func arguments(for mode: ScreenshotCaptureMode, output: URL) -> [String] {
        switch mode {
        case .selectedRegion:
            return ["-i", output.path]
        case .window:
            return ["-w", output.path]
        }
    }
}
