import XCTest
@testable import PageLumenCore

final class PDFUAExternalValidatorTests: XCTestCase {
    func testParsesPassReportAndUsesStrictJSONArguments() throws {
        let runner = RecordingPDFUACommandRunner(result: .init(
            statusCode: 0,
            standardOutput: Data("{\"verdict\":\"pass\",\"findings\":[]}".utf8)
        ))
        let validator = PDFUAExternalValidator(
            executableURL: URL(fileURLWithPath: "/tmp/fake-pdfa11y"),
            runner: runner
        )

        let report = try validator.validate(pdfData: Data("%PDF-1.7".utf8))

        XCTAssertEqual(report, PDFUAExternalValidationReport(tool: "pdfa11y", verdict: "pass", findingCount: 0))
        XCTAssertEqual(runner.arguments.prefix(3), ["--format", "json", "--strict"])
        XCTAssertTrue(runner.arguments.last?.hasSuffix(".pdf") == true)
    }

    func testValidationFailureStatusStillReturnsStructuredReport() throws {
        let runner = RecordingPDFUACommandRunner(result: .init(
            statusCode: 1,
            standardOutput: Data("[{\"verdict\":\"fail\",\"findings\":[{},{}]}]".utf8)
        ))
        let validator = PDFUAExternalValidator(
            executableURL: URL(fileURLWithPath: "/tmp/fake-pdfa11y"),
            runner: runner
        )

        let report = try validator.validate(pdfData: Data("pdf".utf8))

        XCTAssertEqual(report.verdict, "fail")
        XCTAssertEqual(report.findingCount, 2)
    }

    func testMalformedOutputAndToolErrorDoNotClaimConformance() {
        let malformed = PDFUAExternalValidator(
            executableURL: URL(fileURLWithPath: "/tmp/fake-pdfa11y"),
            runner: RecordingPDFUACommandRunner(result: .init(statusCode: 0, standardOutput: Data("{}".utf8)))
        )
        XCTAssertThrowsError(try malformed.validate(pdfData: Data("pdf".utf8))) { error in
            XCTAssertEqual(error as? PDFUAExternalValidationError, .invalidReport)
        }

        let toolError = PDFUAExternalValidator(
            executableURL: URL(fileURLWithPath: "/tmp/fake-pdfa11y"),
            runner: RecordingPDFUACommandRunner(result: .init(statusCode: 2, standardOutput: Data()))
        )
        XCTAssertThrowsError(try toolError.validate(pdfData: Data("pdf".utf8))) { error in
            XCTAssertEqual(error as? PDFUAExternalValidationError, .commandFailed(statusCode: 2))
        }
    }
}

private final class RecordingPDFUACommandRunner: PDFUACommandRunning, @unchecked Sendable {
    let result: PDFUACommandResult
    private(set) var arguments: [String] = []

    init(result: PDFUACommandResult) { self.result = result }

    var requiresInstalledExecutable: Bool { false }

    func run(executable: URL, arguments: [String]) throws -> PDFUACommandResult {
        self.arguments = arguments
        return result
    }
}
