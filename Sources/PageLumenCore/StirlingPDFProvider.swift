import Foundation

/// Connection settings for an optional, user-managed Stirling-PDF instance.
///
/// The API key is intentionally supplied as an in-memory value. Stage A does
/// not persist credentials; the app-shell integration will move it to
/// Keychain before any operation that uploads document content is introduced.
public struct StirlingPDFEndpoint: Sendable, Equatable {
    public var baseURL: URL
    public var apiKey: String?
    public var allowRemoteHTTPS: Bool

    public init(baseURL: URL, apiKey: String? = nil, allowRemoteHTTPS: Bool = false) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.allowRemoteHTTPS = allowRemoteHTTPS
    }

    public func validated() throws -> StirlingPDFEndpoint {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw StirlingPDFEndpointError.invalidURL
        }

        let isLoopback = Self.loopbackHosts.contains(host.lowercased())
        if scheme == "http" {
            guard isLoopback else { throw StirlingPDFEndpointError.remoteHTTPNotAllowed }
        } else if scheme == "https" {
            guard isLoopback || allowRemoteHTTPS else {
                throw StirlingPDFEndpointError.remoteHTTPSRequiresOptIn
            }
        } else {
            throw StirlingPDFEndpointError.unsupportedScheme
        }

        // A base URL may be entered with a trailing slash. Normalising it
        // keeps the probe path deterministic while retaining a reverse proxy
        // prefix such as https://localhost/pagelumen.
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return StirlingPDFEndpoint(
            baseURL: components.url ?? baseURL,
            apiKey: apiKey,
            allowRemoteHTTPS: allowRemoteHTTPS
        )
    }

    fileprivate static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]
}

public enum StirlingPDFEndpointError: Error, Equatable, Sendable {
    case invalidURL
    case unsupportedScheme
    case remoteHTTPNotAllowed
    case remoteHTTPSRequiresOptIn
}

public struct StirlingPDFCapabilities: Codable, Equatable, Sendable {
    public var version: String?
    public var operations: [String]
    public var status: String?

    public init(version: String? = nil, operations: [String] = [], status: String? = nil) {
        self.version = version
        self.operations = operations
        self.status = status
    }
}

public enum StirlingPDFProbeState: Equatable, Sendable {
    case available(StirlingPDFCapabilities)
    case unavailable
    case authenticationRequired
    case timedOut
    case cancelled
    case tlsFailure
    case invalidResponse
    case invalidEndpoint(StirlingPDFEndpointError)
}

public struct StirlingPDFProbeResult: Equatable, Sendable {
    public var state: StirlingPDFProbeState
    public var httpStatusCode: Int?

    public init(state: StirlingPDFProbeState, httpStatusCode: Int? = nil) {
        self.state = state
        self.httpStatusCode = httpStatusCode
    }
}

/// The transport boundary makes capability probing deterministic in tests and
/// prevents the provider from acquiring a hard dependency on a web framework.
public protocol StirlingPDFHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionStirlingPDFHTTPTransport: StirlingPDFHTTPTransport, Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

/// Stage A only performs a metadata GET. It never accepts document data and
/// therefore cannot upload source content during discovery.
public struct StirlingPDFCapabilityProbe: Sendable {
    public static let defaultStatusPath = "api/v1/info/status"

    private let transport: any StirlingPDFHTTPTransport
    private let timeout: TimeInterval
    private let statusPath: String

    public init(
        transport: any StirlingPDFHTTPTransport = URLSessionStirlingPDFHTTPTransport(),
        timeout: TimeInterval = 5,
        statusPath: String = StirlingPDFCapabilityProbe.defaultStatusPath
    ) {
        self.transport = transport
        self.timeout = timeout
        self.statusPath = statusPath
    }

    public func probe(endpoint configuration: StirlingPDFEndpoint) async -> StirlingPDFProbeResult {
        let validatedEndpoint: StirlingPDFEndpoint
        do {
            validatedEndpoint = try configuration.validated()
        } catch let error as StirlingPDFEndpointError {
            return StirlingPDFProbeResult(state: .invalidEndpoint(error))
        } catch {
            return StirlingPDFProbeResult(state: .invalidEndpoint(.invalidURL))
        }

        guard let url = statusURL(for: validatedEndpoint.baseURL) else {
            return StirlingPDFProbeResult(state: .invalidEndpoint(.invalidURL))
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = validatedEndpoint.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        }

        do {
            let (data, response) = try await transport.data(for: request)
            switch response.statusCode {
            case 401, 403:
                return StirlingPDFProbeResult(state: .authenticationRequired, httpStatusCode: response.statusCode)
            case 200..<300:
                guard let capabilities = decodeCapabilities(data) else {
                    return StirlingPDFProbeResult(state: .invalidResponse, httpStatusCode: response.statusCode)
                }
                return StirlingPDFProbeResult(state: .available(capabilities), httpStatusCode: response.statusCode)
            case 404:
                return StirlingPDFProbeResult(state: .invalidResponse, httpStatusCode: response.statusCode)
            default:
                return StirlingPDFProbeResult(state: .unavailable, httpStatusCode: response.statusCode)
            }
        } catch is CancellationError {
            return StirlingPDFProbeResult(state: .cancelled)
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                return StirlingPDFProbeResult(state: .cancelled)
            case .timedOut:
                return StirlingPDFProbeResult(state: .timedOut)
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot, .clientCertificateRejected:
                return StirlingPDFProbeResult(state: .tlsFailure)
            default:
                return StirlingPDFProbeResult(state: .unavailable)
            }
        } catch {
            return StirlingPDFProbeResult(state: .unavailable)
        }
    }

    private func statusURL(for baseURL: URL) -> URL? {
        let path = statusPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { return nil }
        return baseURL.appendingPathComponent(path)
    }

    private func decodeCapabilities(_ data: Data) -> StirlingPDFCapabilities? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let version = (object["version"] as? String) ?? (object["appVersion"] as? String)
        let status = object["status"] as? String
        let keys = ["capabilities", "operations", "features"]
        let operations = keys
            .compactMap { object[$0] as? [String] }
            .flatMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) { result.append(value) }
            }
        // A valid status response may contain only status/version metadata;
        // requiring one of those fields avoids treating arbitrary JSON as a
        // successful capability response.
        guard version != nil || status != nil || !operations.isEmpty else { return nil }
        return StirlingPDFCapabilities(version: version, operations: operations, status: status)
    }
}
