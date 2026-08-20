import Foundation

/// An isolated description of a possible downloaded model. This is metadata
/// only: PageLumen does not download weights or instantiate an inference
/// runtime through this type.
public struct LocalModelPrototypeManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let repositoryURL: URL
    public let revision: String
    public let licenseIdentifier: String
    public let modelCardURL: URL
    public let weightsSizeBytes: Int64
    public let storageRelativePath: String
    public let supportsAppleSilicon: Bool

    public init(schemaVersion: Int = currentSchemaVersion, repositoryURL: URL,
                revision: String, licenseIdentifier: String, modelCardURL: URL,
                weightsSizeBytes: Int64, storageRelativePath: String,
                supportsAppleSilicon: Bool) {
        self.schemaVersion = schemaVersion
        self.repositoryURL = repositoryURL
        self.revision = revision
        self.licenseIdentifier = licenseIdentifier
        self.modelCardURL = modelCardURL
        self.weightsSizeBytes = weightsSizeBytes
        self.storageRelativePath = storageRelativePath
        self.supportsAppleSilicon = supportsAppleSilicon
    }

    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        if schemaVersion != Self.currentSchemaVersion { errors.append(.unsupportedSchemaVersion(schemaVersion)) }
        if repositoryURL.scheme?.lowercased() != "https" { errors.append(.insecureRepositoryURL) }
        if modelCardURL.scheme?.lowercased() != "https" { errors.append(.insecureModelCardURL) }
        if revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.emptyField("revision")) }
        if licenseIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.emptyField("licenseIdentifier")) }
        if weightsSizeBytes <= 0 { errors.append(.invalidWeightsSize) }
        if storageRelativePath.isEmpty || storageRelativePath.hasPrefix("/") || storageRelativePath.contains("..") {
            errors.append(.invalidStoragePath)
        }
        return errors
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case unsupportedSchemaVersion(Int)
        case insecureRepositoryURL
        case insecureModelCardURL
        case emptyField(String)
        case invalidWeightsSize
        case invalidStoragePath
    }
}

public enum LocalModelPrototypeDecision: Equatable, Sendable {
    case eligible
    case denied(Reason)

    public enum Reason: Equatable, Sendable {
        case invalidManifest
        case consentRequired
        case unsupportedDevice
        case defaultPipelineDisabled
        case removalPolicyRequired
    }
}

public enum LocalModelLifecycleState: Equatable, Sendable {
    case unavailable
    case awaitingConsent
    case downloading(progress: Double)
    case ready
    case cancelled
    case removed
    case failed(String)
}

/// Pure state transitions for a future model manager. No network or
/// filesystem mutation is performed by this shipping-safe contract.
public enum LocalModelLifecycle {
    public static func startDownload(from state: LocalModelLifecycleState,
                                     consentGranted: Bool) -> LocalModelLifecycleState {
        guard consentGranted else { return .awaitingConsent }
        guard state == .unavailable || state == .cancelled || state == .removed else { return state }
        return .downloading(progress: 0)
    }

    public static func updateProgress(_ progress: Double,
                                     from state: LocalModelLifecycleState) -> LocalModelLifecycleState {
        guard case .downloading = state else { return state }
        return .downloading(progress: min(max(progress, 0), 1))
    }

    public static func finishDownload(from state: LocalModelLifecycleState) -> LocalModelLifecycleState {
        guard case .downloading(let progress) = state, progress >= 1 else { return state }
        return .ready
    }

    public static func cancel(from state: LocalModelLifecycleState) -> LocalModelLifecycleState {
        guard case .downloading = state else { return state }
        return .cancelled
    }

    public static func removeOffline(from state: LocalModelLifecycleState) -> LocalModelLifecycleState {
        guard state == .ready else { return state }
        return .removed
    }
}

/// Evaluates launch gates for a future prototype without changing the default
/// deterministic pipeline. A caller must explicitly pass consent and opt in;
/// no global setting is mutated here.
public struct LocalModelPrototypeGate: Sendable {
    public init() {}

    public func decision(manifest: LocalModelPrototypeManifest,
                         consentGranted: Bool,
                         appleSiliconAvailable: Bool,
                         removalPolicyConfigured: Bool,
                         prototypeEnabled: Bool) -> LocalModelPrototypeDecision {
        guard manifest.validate().isEmpty else { return .denied(.invalidManifest) }
        guard prototypeEnabled else { return .denied(.defaultPipelineDisabled) }
        guard consentGranted else { return .denied(.consentRequired) }
        guard removalPolicyConfigured else { return .denied(.removalPolicyRequired) }
        guard !manifest.supportsAppleSilicon || appleSiliconAvailable else {
            return .denied(.unsupportedDevice)
        }
        return .eligible
    }
}
