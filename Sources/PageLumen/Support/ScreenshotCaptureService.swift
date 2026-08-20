import AppKit
import CoreGraphics
import Foundation
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#endif

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

enum ScreenshotCaptureError: LocalizedError, Equatable {
    case cancelled
    case commandFailed(Int32)
    case missingOutput
    case permissionDenied
    case modernAPINotAvailable
    case noShareableContent
    case modernCaptureFailed(String)

    static func legacyTerminationError(status: Int32, isCancelled: Bool = Task.isCancelled) -> Self {
        if isCancelled || status == 1 {
            return .cancelled
        }
        return .commandFailed(status)
    }

    static func modernCaptureError(_ error: Error, isCancelled: Bool = Task.isCancelled) -> Self {
        if isCancelled || error is CancellationError {
            return .cancelled
        }
        return .modernCaptureFailed(error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Screenshot capture was cancelled."
        case .commandFailed(let status):
            return "Screenshot capture failed with status \(status)."
        case .missingOutput:
            return "No screenshot was captured."
        case .permissionDenied:
            return "Screen capture permission was not granted. Allow it in System Settings > Privacy & Security > Screen Recording."
        case .modernAPINotAvailable:
            return "The modern screen-capture API requires macOS 14 or later."
        case .noShareableContent:
            return "No windows or displays are available for capture."
        case .modernCaptureFailed(let reason):
            return "The modern screen-capture API failed: \(reason)."
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
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenshotCaptureError.permissionDenied
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(mode.filePrefix)-\(UUID().uuidString)")
            .appendingPathExtension("png")

        // `screencapture -i/-w` presents Apple's interactive region/window
        // picker. Never silently choose the first on-screen window.
        return try await legacyCapture(mode: mode, outputURL: url)
    }

    @available(macOS 14.0, *)
    private func captureWithScreenshotManager(mode: ScreenshotCaptureMode, outputURL: URL) async throws -> URL {
        #if canImport(ScreenCaptureKit)
        let content = try await SCShareableContent.current
        let targetWindow: SCWindow? = {
            switch mode {
            case .window:
                return content.windows.first { $0.isOnScreen && $0.windowLayer == 0 }
            case .selectedRegion:
                // Region selection requires a drag UI which the modern API
                // does not expose as a one-shot call. Defer to the legacy
                // `screencapture -i` interactive picker.
                return nil
            }
        }()

        if let window = targetWindow {
            return try await captureWindow(window, outputURL: outputURL)
        }
        #endif
        throw ScreenshotCaptureError.modernAPINotAvailable
    }

    #if canImport(ScreenCaptureKit)
    @available(macOS 14.0, *)
    private func captureWindow(_ window: SCWindow, outputURL: URL) async throws -> URL {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = false
        configuration.showsCursor = false

        if #available(macOS 26.0, *) {
            #if canImport(UniformTypeIdentifiers)
            return try await captureScreenshot(filter: filter, configuration: configuration, outputURL: outputURL)
            #else
            return try await captureImage(filter: filter, configuration: configuration, outputURL: outputURL)
            #endif
        } else {
            return try await captureImage(filter: filter, configuration: configuration, outputURL: outputURL)
        }
    }

    @available(macOS 14.0, *)
    private func captureImage(filter: SCContentFilter, configuration: SCStreamConfiguration, outputURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { cgImage, error in
                if let error {
                    continuation.resume(throwing: ScreenshotCaptureError.modernCaptureError(error))
                    return
                }
                guard let cgImage else {
                    continuation.resume(throwing: ScreenshotCaptureError.missingOutput)
                    return
                }
                do {
                    try writeCGImage(cgImage, to: outputURL)
                    continuation.resume(returning: outputURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(macOS 26.0, *)
    private func captureScreenshot(filter: SCContentFilter, configuration: SCStreamConfiguration, outputURL: URL) async throws -> URL {
        #if canImport(UniformTypeIdentifiers)
        let screenshotConfig = SCScreenshotConfiguration()
        screenshotConfig.contentType = UTType.png as UTTypeReference
        screenshotConfig.fileURL = outputURL
        screenshotConfig.showsCursor = false

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: screenshotConfig) { output, error in
                if let error {
                    continuation.resume(throwing: ScreenshotCaptureError.modernCaptureError(error))
                    return
                }
                guard output != nil else {
                    continuation.resume(throwing: ScreenshotCaptureError.missingOutput)
                    return
                }
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: ScreenshotCaptureError.missingOutput)
                }
            }
        }
        #else
        return try await captureImage(filter: filter, configuration: configuration, outputURL: outputURL)
        #endif
    }

    private func writeCGImage(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw ScreenshotCaptureError.missingOutput
        }
        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) {
            throw ScreenshotCaptureError.missingOutput
        }
    }
    #endif

    private func legacyCapture(mode: ScreenshotCaptureMode, outputURL: URL) async throws -> URL {
        guard !Task.isCancelled else {
            throw ScreenshotCaptureError.cancelled
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments(for: mode, output: outputURL)

        try process.run()
        process.waitUntilExit()

        if Task.isCancelled {
            try? FileManager.default.removeItem(at: outputURL)
            throw ScreenshotCaptureError.cancelled
        }

        guard process.terminationStatus == 0 else {
            throw ScreenshotCaptureError.legacyTerminationError(status: process.terminationStatus)
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
