import Foundation

/// A process boundary for an optional developer/CI PDF/UA validator.
/// Production app code never invokes this boundary automatically.
public protocol PDFUACommandRunning: Sendable {
    var requiresInstalledExecutable: Bool { get }
    func run(executable: URL, arguments: [String]) throws -> PDFUACommandResult
}

public extension PDFUACommandRunning {
    var requiresInstalledExecutable: Bool { true }
}

public struct PDFUACommandResult: Equatable, Sendable {
    public let statusCode: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(statusCode: Int32, standardOutput: Data, standardError: Data = Data()) {
        self.statusCode = statusCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum PDFUAExternalValidationError: Error, Equatable, Sendable {
    case executableMissing
    case commandFailed(statusCode: Int32)
    case invalidReport
    case outputTooLarge
}

public struct PDFUAExternalValidationReport: Codable, Equatable, Sendable {
    public let tool: String
    public let verdict: String
    public let findingCount: Int

    public init(tool: String, verdict: String, findingCount: Int) {
        self.tool = tool
        self.verdict = verdict
        self.findingCount = findingCount
    }
}

/// Optional adapter for `speedata/pdfa11y`.
///
/// The MIT-licensed CLI is a developer/CI tool only: it is not embedded in the
/// app, is not an SPM dependency, and is never run on user documents by the
/// shipping product. A non-zero validation result (typically status 1) is
/// parsed and returned; status 2 and malformed output are tool failures.
public struct PDFUAExternalValidator: Sendable {
    public static let defaultExecutableURL = URL(fileURLWithPath: "/usr/local/bin/pdfa11y")
    public static let maximumReportBytes = 2 * 1024 * 1024

    private let executableURL: URL
    private let runner: any PDFUACommandRunning

    public init(
        executableURL: URL = PDFUAExternalValidator.defaultExecutableURL,
        runner: any PDFUACommandRunning = FoundationPDFUACommandRunner()
    ) {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func validate(pdfData: Data) throws -> PDFUAExternalValidationReport {
        guard !runner.requiresInstalledExecutable || FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw PDFUAExternalValidationError.executableMissing
        }
        guard !pdfData.isEmpty else { throw PDFUAExternalValidationError.invalidReport }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pagelumen-pdfua-(UUID().uuidString)")
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try pdfData.write(to: temporaryURL, options: .atomic)

        let result = try runner.run(
            executable: executableURL,
            arguments: ["--format", "json", "--strict", temporaryURL.path]
        )
        guard result.standardOutput.count <= Self.maximumReportBytes else {
            throw PDFUAExternalValidationError.outputTooLarge
        }
        guard result.statusCode != 2 else {
            throw PDFUAExternalValidationError.commandFailed(statusCode: result.statusCode)
        }
        guard let report = Self.parse(data: result.standardOutput) else {
            throw PDFUAExternalValidationError.invalidReport
        }
        return report
    }

    private static func parse(data: Data) -> PDFUAExternalValidationReport? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let dictionary: [String: Any]
        if let value = object as? [String: Any] {
            dictionary = value
        } else if let values = object as? [[String: Any]], let first = values.first {
            dictionary = first
        } else {
            return nil
        }
        let verdict = (dictionary["verdict"] as? String)
            ?? (dictionary["status"] as? String)
            ?? (dictionary["result"] as? String)
        guard let verdict, !verdict.isEmpty else { return nil }
        let findingCount: Int
        if let findings = dictionary["findings"] as? [Any] {
            findingCount = findings.count
        } else if let count = dictionary["findingCount"] as? Int {
            findingCount = count
        } else {
            findingCount = 0
        }
        return PDFUAExternalValidationReport(tool: "pdfa11y", verdict: verdict, findingCount: findingCount)
    }
}

public struct FoundationPDFUACommandRunner: PDFUACommandRunning {
    public init() {}

    public func run(executable: URL, arguments: [String]) throws -> PDFUACommandResult {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        return PDFUACommandResult(
            statusCode: process.terminationStatus,
            standardOutput: output.fileHandleForReading.readDataToEndOfFile(),
            standardError: error.fileHandleForReading.readDataToEndOfFile()
        )
    }
}
