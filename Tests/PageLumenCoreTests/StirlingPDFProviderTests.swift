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

    private func localEndpoint() -> StirlingPDFEndpoint {
        StirlingPDFEndpoint(baseURL: URL(string: "http://127.0.0.1:8080")!)
    }

}

private func makeResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
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
