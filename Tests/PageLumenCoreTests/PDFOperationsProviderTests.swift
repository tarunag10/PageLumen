import Foundation
import XCTest
@testable import PageLumenCore

@MainActor
@MainActor
final class PDFOperationsProviderTests: XCTestCase {
    func testNativeProviderValidatesLocallyWithoutNetworkSemantics() async throws {
        let input = try Data(contentsOf: Fixtures.tinyPDF(text: "native"))
        let provider = NativePDFOperationsProvider()
        XCTAssertEqual(provider.providerID, "native-pdfkit")
        XCTAssertEqual(provider.supportedOperations, [.validate])

        let result = try await provider.execute(PDFOperationRequest(
            operation: .validate,
            documents: [(data: input, filename: "native.pdf")]
        ))
        XCTAssertEqual(result.operation, .validate)
        XCTAssertEqual(result.providerID, provider.providerID)
        XCTAssertEqual(result.data, input)
    }

    func testNativeProviderRejectsUnsupportedTransformation() async throws {
        let input = Data("not-needed-for-unsupported".utf8)
        await XCTAssertThrowsErrorAsync(try await NativePDFOperationsProvider().execute(
            PDFOperationRequest(operation: .compress, documents: [(data: input, filename: "input.pdf")])
        )) { error in
            XCTAssertEqual(error as? PDFOperationsProviderError, .unsupportedOperation(.compress))
        }
    }

    func testStirlingAdapterIsOptInAndMapsCompressionResult() async throws {
        let input = try Data(contentsOf: Fixtures.tinyPDF(text: "stirling"))
        let transport = ProviderStubTransport { request in
            XCTAssertEqual(request.url?.path, "/api/v1/misc/compress-pdf")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-KEY"), "secret")
            return (input, makeProviderResponse(for: request, statusCode: 200, contentType: "application/pdf"))
        }
        let provider = StirlingPDFOperationsProvider(
            endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://127.0.0.1:8080")!, apiKey: "secret"),
            transport: transport
        )
        XCTAssertEqual(provider.supportedOperations, [.compress, .merge])

        let result = try await provider.execute(PDFOperationRequest(
            operation: .compress,
            documents: [(data: input, filename: "input.pdf")]
        ))
        XCTAssertEqual(result.providerID, "stirling-pdf")
        XCTAssertEqual(result.operation, .compress)
        XCTAssertEqual(result.data, input)
    }

    func testStirlingAdapterDoesNotProbeOrContactUntilExecute() async throws {
        let transport = ProviderStubTransport { _ in
            XCTFail("provider construction must not contact the endpoint")
            throw URLError(.badServerResponse)
        }
        _ = StirlingPDFOperationsProvider(
            endpoint: StirlingPDFEndpoint(baseURL: URL(string: "http://localhost")!),
            transport: transport
        )
    }

}

private func makeProviderResponse(for request: URLRequest, statusCode: Int, contentType: String) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": contentType])!
}

private struct ProviderStubTransport: StirlingPDFHTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await handler(request)
    }
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
