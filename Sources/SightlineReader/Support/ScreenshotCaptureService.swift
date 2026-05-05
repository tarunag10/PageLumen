import Foundation

enum ScreenshotCaptureMode {
    case selectedRegion
    case window

    var filePrefix: String {
        switch self {
        case .selectedRegion:
            return "Sightline-Selection"
        case .window:
            return "Sightline-Window"
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
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(mode.filePrefix)-\(UUID().uuidString)")
            .appendingPathExtension("png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments(for: mode, output: url)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ScreenshotCaptureError.commandFailed(process.terminationStatus)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScreenshotCaptureError.missingOutput
        }

        return url
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
