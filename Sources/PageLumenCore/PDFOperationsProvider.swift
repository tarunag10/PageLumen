import Foundation
import PDFKit

/// A deliberately small, typed boundary for optional PDF transformations.
///
/// The request contains bytes only after the caller has made an explicit
/// operation decision. Providers must not discover, upload, or persist source
/// documents as part of capability reporting.
public enum PDFOperationKind: String, Codable, Hashable, Sendable {
    case validate
    case compress
    case merge
}

public struct PDFOperationRequest: Sendable {
    public let operation: PDFOperationKind
    public let documents: [(data: Data, filename: String)]

    public init(operation: PDFOperationKind, documents: [(data: Data, filename: String)]) {
        self.operation = operation
        self.documents = documents
    }
}

public struct PDFOperationResult: Sendable {
    public let operation: PDFOperationKind
    public let providerID: String
    public let data: Data

    public init(operation: PDFOperationKind, providerID: String, data: Data) {
        self.operation = operation
        self.providerID = providerID
        self.data = data
    }
}

public enum PDFOperationsProviderError: Error, Equatable, Sendable {
    case unsupportedOperation(PDFOperationKind)
    case invalidRequest
    case invalidPDF
}

/// Common seam for native PDFKit/Vision functionality and opt-in external
/// providers. The default app path can depend on this protocol without
/// acquiring an HTTP client or a Stirling server.
public protocol PDFOperationsProvider: Sendable {
    var providerID: String { get }
    var supportedOperations: Set<PDFOperationKind> { get }
    func execute(_ request: PDFOperationRequest) async throws -> PDFOperationResult
}

/// The default provider is intentionally local. Validation is useful to every
/// workflow; transformations not yet implemented natively fail explicitly.
public struct NativePDFOperationsProvider: PDFOperationsProvider, Sendable {
    public let providerID = "native-pdfkit"
    public let supportedOperations: Set<PDFOperationKind> = [.validate]

    public init() {}

    public func execute(_ request: PDFOperationRequest) async throws -> PDFOperationResult {
        guard request.operation == .validate, request.documents.count == 1,
              let document = PDFDocument(data: request.documents[0].data),
              document.pageCount > 0 else {
            if request.operation != .validate {
                throw PDFOperationsProviderError.unsupportedOperation(request.operation)
            }
            throw PDFOperationsProviderError.invalidPDF
        }
        return PDFOperationResult(operation: .validate, providerID: providerID, data: request.documents[0].data)
    }
}

/// An opt-in adapter. Constructing this value does not contact the endpoint;
/// upload happens only when the caller executes a request with document bytes.
public struct StirlingPDFOperationsProvider: PDFOperationsProvider, Sendable {
    public let providerID = "stirling-pdf"
    public let supportedOperations: Set<PDFOperationKind> = [.compress, .merge]

    private let endpoint: StirlingPDFEndpoint
    private let compressor: StirlingPDFCompressor
    private let merger: StirlingPDFMerger

    public init(
        endpoint: StirlingPDFEndpoint,
        transport: any StirlingPDFHTTPTransport = URLSessionStirlingPDFHTTPTransport()
    ) {
        self.endpoint = endpoint
        self.compressor = StirlingPDFCompressor(transport: transport)
        self.merger = StirlingPDFMerger(transport: transport)
    }

    public func execute(_ request: PDFOperationRequest) async throws -> PDFOperationResult {
        guard supportedOperations.contains(request.operation) else {
            throw PDFOperationsProviderError.unsupportedOperation(request.operation)
        }
        switch request.operation {
        case .compress:
            guard request.documents.count == 1 else { throw PDFOperationsProviderError.invalidRequest }
            let result = try await compressor.compress(
                data: request.documents[0].data,
                filename: request.documents[0].filename,
                endpoint: endpoint
            )
            return PDFOperationResult(operation: .compress, providerID: providerID, data: result.data)
        case .merge:
            guard request.documents.count >= 2 else { throw PDFOperationsProviderError.invalidRequest }
            let result = try await merger.merge(inputs: request.documents, endpoint: endpoint)
            return PDFOperationResult(operation: .merge, providerID: providerID, data: result.data)
        case .validate:
            throw PDFOperationsProviderError.unsupportedOperation(.validate)
        }
    }
}
