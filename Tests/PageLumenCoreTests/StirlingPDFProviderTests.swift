import Foundation
import XCTest
@testable import PageLumenCore

final class StirlingPDFProviderTests: XCTestCase {
    func testProbeReadsMetadataWithoutUploadingContent() async throws {
        let transport = StubTransport { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.httpBody)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-KEY"), "test-key")
            XCTAssertEqual(request.url?.path, "/api/v1/info/status")
            return (Data(#"{"status":"UP","version":"0.40.0","capabilities":["compress","merge"],"features":["merge"]}"#.utf8), makeResponse(for: request, statusCode: 200))
        }

        let result = await StirlingPDFCapabilityProbe(transport: transport).probe(
            endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://localhost")!, apiKey: "test-key")
        )

        XCTAssertEqual(result.httpStatusCode, 200)
        XCTAssertEqual(result.state, .available(StirlingPDFCapabilities(version: "0.40.0", operations: ["compress", "merge"], status: "UP")))
    }

    func testProbeDistinguishesAuthenticationFailure() async {
        let transport = StubTransport { request in
            (Data(), makeResponse(for: request, statusCode: 401))
        }
        let result = await StirlingPDFCapabilityProbe(transport: transport).probe(endpoint: localEndpoint())
        XCTAssertEqual(result.state, .authenticationRequired)
        XCTAssertEqual(result.httpStatusCode, 401)
    }

    func testProbeRejectsMalformedSuccessfulResponse() async {
        let transport = StubTransport { request in
            (Data(#"{"message":"not a status response"}"#.utf8), makeResponse(for: request, statusCode: 200))
        }
        let result = await StirlingPDFCapabilityProbe(transport: transport).probe(endpoint: localEndpoint())
        XCTAssertEqual(result.state, .invalidResponse)
    }

    func testProbeMapsTimeoutAndCancellation() async {
        let timedOut = StubTransport { _ in throw URLError(.timedOut) }
        let timeoutResult = await StirlingPDFCapabilityProbe(transport: timedOut).probe(endpoint: localEndpoint())
        XCTAssertEqual(timeoutResult.state, .timedOut)

        let cancelled = StubTransport { _ in throw CancellationError() }
        let cancellationResult = await StirlingPDFCapabilityProbe(transport: cancelled).probe(endpoint: localEndpoint())
        XCTAssertEqual(cancellationResult.state, .cancelled)
    }

    func testProbeRequiresLoopbackHTTPAndExplicitRemoteHTTPSOptIn() async {
        let transport = StubTransport { request in
            (Data(#"{"status":"UP"}"#.utf8), makeResponse(for: request, statusCode: 200))
        }
        let probe = StirlingPDFCapabilityProbe(transport: transport)

        let remoteHTTP = await probe.probe(endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://example.com")!))
        XCTAssertEqual(remoteHTTP.state, .invalidEndpoint(.remoteHTTPNotAllowed))

        let remoteHTTPS = await probe.probe(endpoint: StirlingPDFEndpoint(baseURL: URL(string: "https://example.com")!))
        XCTAssertEqual(remoteHTTPS.state, .invalidEndpoint(.remoteHTTPSRequiresOptIn))

        let optedIn = await probe.probe(endpoint: StirlingPDFEndpoint(baseURL: URL(string: "https://example.com")!, allowRemoteHTTPS: true))
        XCTAssertEqual(optedIn.state, .available(StirlingPDFCapabilities(status: "UP")))
    }

    func testProbeRejectsCredentialsAndUnsupportedSchemes() async {
        let probe = StirlingPDFCapabilityProbe(transport: StubTransport { request in
            (Data(), makeResponse(for: request, statusCode: 200))
        })
        let credentials = await probe.probe(endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://user:pass@localhost")!))
        XCTAssertEqual(credentials.state, .invalidEndpoint(.invalidURL))
        let file = await probe.probe(endpoint: StirlingPDFEndpoint(baseURL: URL(string: "file:///tmp/stirling")!))
        XCTAssertEqual(file.state, .invalidEndpoint(.invalidURL))
    }

    @MainActor
    func testCompressUsesDocumentedMultipartRequestWithoutLeakingKey() async throws {
        let input = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "input")))
        let transport = StubTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/misc/compress-pdf")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/pdf")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-KEY"), "secret")
            let body = try XCTUnwrap(request.httpBody)
            XCTAssertTrue(String(decoding: body, as: UTF8.self).contains("name=\"fileInput\""))
            XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("secret"))
            XCTAssertNotNil(body.range(of: input))
            return (input, makeResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        }

        let result = try await StirlingPDFCompressor(transport: transport).compress(
            data: input,
            filename: "../../private.pdf",
            endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://localhost:8080")!, apiKey: "secret")
        )
        XCTAssertEqual(result.data, input)
        XCTAssertEqual(result.httpStatusCode, 200)
    }

    @MainActor
    func testCompressMapsAuthenticationAndHTTPFailures() async throws {
        let input = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "input")))
        let auth = StirlingPDFCompressor(transport: StubTransport { request in
            (Data(), makeResponse(for: request, statusCode: 403))
        })
        await XCTAssertThrowsErrorAsync(try await auth.compress(data: input, endpoint: localEndpoint())) { error in
            XCTAssertEqual(error as? StirlingPDFCompressionError, .authenticationRequired(statusCode: 403))
        }

        let failed = StirlingPDFCompressor(transport: StubTransport { request in
            (Data(), makeResponse(for: request, statusCode: 422))
        })
        await XCTAssertThrowsErrorAsync(try await failed.compress(data: input, endpoint: localEndpoint())) { error in
            XCTAssertEqual(error as? StirlingPDFCompressionError, .requestFailed(statusCode: 422))
        }
    }

    @MainActor
    func testCompressMapsCancellationAndMalformedOutput() async throws {
        let input = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "input")))
        let cancelled = StirlingPDFCompressor(transport: StubTransport { _ in throw CancellationError() })
        await XCTAssertThrowsErrorAsync(try await cancelled.compress(data: input, endpoint: localEndpoint())) { error in
            XCTAssertEqual(error as? StirlingPDFCompressionError, .cancelled)
        }

        let malformed = StirlingPDFCompressor(transport: StubTransport { request in
            (Data("not a PDF".utf8), makeResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        })
        await XCTAssertThrowsErrorAsync(try await malformed.compress(data: input, endpoint: localEndpoint())) { error in
            XCTAssertEqual(error as? StirlingPDFCompressionError, .outputIsNotPDF)
        }
    }

    @MainActor
    func testCompressRejectsRemoteEndpointAndAtomicWriterValidatesPDF() async throws {
        let input = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "input")))
        let compressor = StirlingPDFCompressor(transport: StubTransport { request in
            XCTFail("transport must not be called for an unvalidated endpoint")
            return (input, makeResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        })
        await XCTAssertThrowsErrorAsync(try await compressor.compress(
            data: input,
            endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://example.com")!)
        )) { error in
            XCTAssertEqual(error as? StirlingPDFCompressionError, .invalidEndpoint(.remoteHTTPNotAllowed))
        }

        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try StirlingPDFAtomicOutput.write(input, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), input)
        XCTAssertThrowsError(try StirlingPDFAtomicOutput.write(Data("bad".utf8), to: destination)) { error in
            XCTAssertEqual(error as? StirlingPDFCompressionError, .outputIsNotPDF)
        }
        try? FileManager.default.removeItem(at: destination)
    }

    @MainActor
    func testMergeUsesRepeatedMultipartInputsAndValidatesPDF() async throws {
        let first = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "one")))
        let second = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "two")))
        let transport = StubTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/general/merge-pdfs")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-KEY"), "secret")
            let body = try XCTUnwrap(request.httpBody)
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertEqual(bodyText.components(separatedBy: "name=\"fileInput\"").count - 1, 2)
            XCTAssertTrue(bodyText.contains("filename=\"one.pdf\""))
            XCTAssertTrue(bodyText.contains("filename=\"two.pdf\""))
            XCTAssertFalse(bodyText.contains("secret"))
            XCTAssertNotNil(body.range(of: first))
            XCTAssertNotNil(body.range(of: second))
            return (first, makeResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        }
        let result = try await StirlingPDFMerger(transport: transport).merge(
            inputs: [(first, "one.pdf"), (second, "nested/two.pdf")],
            endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://localhost:8080")!, apiKey: "secret")
        )
        XCTAssertEqual(result.data, first)
        XCTAssertEqual(result.httpStatusCode, 200)
    }

    @MainActor
    func testMergeEnforcesCountSizeAndCancellationBoundaries() async throws {
        let input = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "input")))
        let merger = StirlingPDFMerger(transport: StubTransport { request in
            XCTFail("transport must not be called for invalid merge input")
            return (input, makeResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        })
        await XCTAssertThrowsErrorAsync(try await merger.merge(inputs: [(input, "only.pdf")], endpoint: localEndpoint())) { error in
            XCTAssertEqual(error as? StirlingPDFMergeError, .tooFewInputs)
        }
        await XCTAssertThrowsErrorAsync(try await merger.merge(
            inputs: [(input, "one.pdf"), (input, "two.pdf")], endpoint: localEndpoint(), maximumTotalInputBytes: 1
        )) { error in
            XCTAssertEqual(error as? StirlingPDFMergeError, .inputTooLarge(limit: 1))
        }
        await XCTAssertThrowsErrorAsync(try await merger.merge(
            inputs: Array(repeating: (input, "copy.pdf"), count: 3), endpoint: localEndpoint(), maximumInputCount: 2
        )) { error in
            XCTAssertEqual(error as? StirlingPDFMergeError, .tooManyInputs(limit: 2))
        }
        let cancelled = StirlingPDFMerger(transport: StubTransport { _ in throw CancellationError() })
        await XCTAssertThrowsErrorAsync(try await cancelled.merge(
            inputs: [(input, "one.pdf"), (input, "two.pdf")], endpoint: localEndpoint()
        )) { error in
            XCTAssertEqual(error as? StirlingPDFMergeError, .cancelled)
        }
    }

    @MainActor
    func testMergeMapsAuthenticationAndMalformedOutput() async throws {
        let input = try XCTUnwrap(Data(contentsOf: Fixtures.tinyPDF(text: "input")))
        let auth = StirlingPDFMerger(transport: StubTransport { request in
            (Data(), makeResponse(for: request, statusCode: 401))
        })
        await XCTAssertThrowsErrorAsync(try await auth.merge(
            inputs: [(input, "one.pdf"), (input, "two.pdf")], endpoint: localEndpoint()
        )) { error in
            XCTAssertEqual(error as? StirlingPDFMergeError, .authenticationRequired(statusCode: 401))
        }
        let malformed = StirlingPDFMerger(transport: StubTransport { request in
            (Data("bad".utf8), makeResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        })
        await XCTAssertThrowsErrorAsync(try await malformed.merge(
            inputs: [(input, "one.pdf"), (input, "two.pdf")], endpoint: localEndpoint()
        )) { error in
            XCTAssertEqual(error as? StirlingPDFMergeError, .outputIsNotPDF)
        }
    }

    private func localEndpoint() -> StirlingPDFEndpoint {
        StirlingPDFEndpoint(baseURL: URL(string: "http://127.0.0.1:8080")!)
    }

}

private func makeResponse(for request: URLRequest, statusCode: Int, contentType: String = "application/json") -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": contentType])!
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ handler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        handler(error)
    }
}

private struct StubTransport: StirlingPDFHTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await handler(request)
    }
}
