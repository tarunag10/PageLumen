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

/// Describes which user-controlled selection surface is available. The
/// capability is intentionally observable without presenting system UI so the
/// app can explain its behavior and tests can assert that no window is ever
/// selected implicitly.
enum ScreenshotCaptureSelectionCapability: Equatable {
    case contentSharingPicker
    case legacyInteractivePicker

    var displayName: String {
        switch self {
        case .contentSharingPicker:
            return "macOS content sharing picker"
        case .legacyInteractivePicker:
            return "macOS interactive screenshot picker"
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
    private let temporaryDirectory: URL

    init(temporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        self.temporaryDirectory = temporaryDirectory
        Self.cleanupStaleTemporaryCaptures(in: temporaryDirectory)
    }

    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// The modern picker is available on macOS 14 and later. It is a
    /// capability contract rather than a promise that capture will succeed:
    /// permission, cancellation, and picker failures remain user-visible.
    var windowSelectionCapability: ScreenshotCaptureSelectionCapability {
        #if canImport(ScreenCaptureKit)
        if #available(macOS 14.0, *) {
            return .contentSharingPicker
        }
        #endif
        return .legacyInteractivePicker
    }

    @discardableResult
    static func cleanupStaleTemporaryCaptures(
        in directory: URL = FileManager.default.temporaryDirectory,
        olderThan age: TimeInterval = 24 * 60 * 60,
        now: Date = Date()
    ) -> Int {
        let cutoff = now.addingTimeInterval(-max(0, age))
        let prefixes = [ScreenshotCaptureMode.selectedRegion.filePrefix, ScreenshotCaptureMode.window.filePrefix]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var removed = 0
        for url in urls where url.pathExtension.lowercased() == "png" && prefixes.contains(where: { url.lastPathComponent.hasPrefix($0 + "-") }) {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            if (try? FileManager.default.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }

    func capture(mode: ScreenshotCaptureMode) async throws -> URL {
        // Prompt the system for screen-capture access on first use. The
        // `screencapture` binary requires this TCC permission; calling the
        // accessor surfaces the standard system prompt the first time the
        // user invokes capture. Subsequent invocations are no-ops if access
        // has already been granted.
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenshotCaptureError.permissionDenied
        }

        let url = temporaryDirectory
            .appendingPathComponent("\(mode.filePrefix)-\(UUID().uuidString)")
            .appendingPathExtension("png")

        switch mode {
        case .selectedRegion:
            // SCContentSharingPicker intentionally does not provide a freeform
            // rectangle. Keep Apple's interactive region picker for this mode.
            return try await legacyCapture(mode: mode, outputURL: url)
        case .window:
            #if canImport(ScreenCaptureKit)
            if #available(macOS 14.0, *) {
                // The picker returns the person's selected filter. There is no
                // fallback after cancellation or API failure, and no content
                // is inspected before the selection callback.
                return try await captureWithContentSharingPicker(outputURL: url)
            }
            #endif
            return try await legacyCapture(mode: mode, outputURL: url)
        }
    }

    #if canImport(ScreenCaptureKit)
    @available(macOS 14.0, *)
    private func captureWithContentSharingPicker(outputURL: URL) async throws -> URL {
        let picker = SCContentSharingPicker.shared
        var configuration = picker.defaultConfiguration
        configuration.allowedPickerModes = .singleWindow
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration

        let observer = ContentSharingPickerObserver()
        picker.add(observer)
        picker.isActive = true
        defer {
            picker.remove(observer)
            picker.isActive = false
        }

        do {
            let filter = try await withTaskCancellationHandler(operation: {
                try await observer.waitForSelection {
                    picker.present(using: .window)
                }
            }, onCancel: {
                observer.cancel()
            })
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = false
            configuration.showsCursor = false
            return try await captureImage(
                filter: filter,
                configuration: configuration,
                outputURL: outputURL
            )
        } catch {
            throw ScreenshotCaptureError.modernCaptureError(error)
        }
    }

    @available(macOS 14.0, *)
    private final class ContentSharingPickerObserver: NSObject, SCContentSharingPickerObserver {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<SCContentFilter, Error>?
        private var completed = false

        func waitForSelection(present: () -> Void) async throws -> SCContentFilter {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                let alreadyCompleted = completed
                lock.unlock()
                if !alreadyCompleted {
                    present()
                }
            }
        }

        func cancel() {
            finish(.failure(CancellationError()))
        }

        func contentSharingPicker(
            _ picker: SCContentSharingPicker,
            didCancelFor stream: SCStream?
        ) {
            finish(.failure(ScreenshotCaptureError.cancelled))
        }

        func contentSharingPicker(
            _ picker: SCContentSharingPicker,
            didUpdateWith filter: SCContentFilter,
            for stream: SCStream?
        ) {
            finish(.success(filter))
        }

        func contentSharingPickerStartDidFailWithError(_ error: Error) {
            finish(.failure(error))
        }

        private func finish(_ result: Result<SCContentFilter, Error>) {
            lock.lock()
            guard !completed else {
                lock.unlock()
                return
            }
            completed = true
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(with: result)
        }
    }
    #endif

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
        process.arguments = legacyArguments(for: mode, output: outputURL)

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

    /// Kept deterministic and internal so the non-interactive command contract
    /// can be regression-tested without launching the system picker.
    func legacyArguments(for mode: ScreenshotCaptureMode, output: URL) -> [String] {
        switch mode {
        case .selectedRegion:
            return ["-i", output.path]
        case .window:
            return ["-w", output.path]
        }
    }
}
