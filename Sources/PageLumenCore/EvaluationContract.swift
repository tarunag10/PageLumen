import Foundation

/// Versioned, privacy-preserving contract for AI evaluation artifacts.
///
/// Evaluation documents and reports are deliberately separate from product
/// documents. The contract can describe a not-yet-run evaluation without
/// turning unavailable values into fabricated zeros or passing scores.
public enum EvaluationContract {
    public static let currentSchemaVersion = 1
    public static let requiredAdversarialTags: Set<String> = [
        "incorrect-ocr",
        "misleading-caption",
        "conflicting-values",
        "hidden-text",
        "chart-without-values",
        "multilingual",
        "sensitive-legal-medical-like"
    ]

    public enum ConsentStatus: String, Codable, Sendable {
        case pending
        case approved
        case withdrawn
    }

    public struct Consent: Codable, Equatable, Sendable {
        public let consentVersion: String
        public let status: ConsentStatus
        public let purpose: String
        public let collectionScope: String
        public let retentionPolicy: String
        public let withdrawalProcess: String
        public let productDocumentsExcluded: Bool

        public init(consentVersion: String, status: ConsentStatus, purpose: String,
                    collectionScope: String, retentionPolicy: String,
                    withdrawalProcess: String, productDocumentsExcluded: Bool) {
            self.consentVersion = consentVersion
            self.status = status
            self.purpose = purpose
            self.collectionScope = collectionScope
            self.retentionPolicy = retentionPolicy
            self.withdrawalProcess = withdrawalProcess
            self.productDocumentsExcluded = productDocumentsExcluded
        }
    }

    public struct Sample: Codable, Equatable, Sendable {
        public let id: String
        public let className: String
        public let sensitivity: String
        public let language: String
        public let adversarialTags: [String]
        public let groundTruthStatus: String
        public let sourceReference: String

        public init(id: String, className: String, sensitivity: String, language: String,
                    adversarialTags: [String], groundTruthStatus: String,
                    sourceReference: String) {
            self.id = id
            self.className = className
            self.sensitivity = sensitivity
            self.language = language
            self.adversarialTags = adversarialTags
            self.groundTruthStatus = groundTruthStatus
            self.sourceReference = sourceReference
        }
    }

    public struct CorpusManifest: Codable, Equatable, Sendable {
        public let schemaVersion: Int
        public let corpusID: String
        public let revision: String
        public let consent: Consent
        public let samples: [Sample]

        public init(schemaVersion: Int = EvaluationContract.currentSchemaVersion,
                    corpusID: String, revision: String, consent: Consent,
                    samples: [Sample]) {
            self.schemaVersion = schemaVersion
            self.corpusID = corpusID
            self.revision = revision
            self.consent = consent
            self.samples = samples
        }
    }

    public enum MetricStatus: String, Codable, Sendable {
        case unavailable
        case measured
    }

    public struct MetricDefinition: Codable, Equatable, Sendable {
        public let id: String
        public let task: String
        public let unit: String
        public let direction: String
        public let threshold: Double?
        public let thresholdSource: String

        public init(id: String, task: String, unit: String, direction: String,
                    threshold: Double?, thresholdSource: String) {
            self.id = id
            self.task = task
            self.unit = unit
            self.direction = direction
            self.threshold = threshold
            self.thresholdSource = thresholdSource
        }
    }

    public struct MetricResult: Codable, Equatable, Sendable {
        public let metricID: String
        public let status: MetricStatus
        public let value: Double?
        public let unavailableReason: String?

        public init(metricID: String, status: MetricStatus, value: Double?,
                    unavailableReason: String?) {
            self.metricID = metricID
            self.status = status
            self.value = value
            self.unavailableReason = unavailableReason
        }
    }

    public struct RunMetadata: Codable, Equatable, Sendable {
        public let runID: String
        public let corpusRevision: String
        public let modelIdentifier: String
        public let xcodeVersion: String
        public let macOSVersion: String
        public let deviceIdentifier: String
        public let processingProfile: String

        public init(runID: String, corpusRevision: String, modelIdentifier: String,
                    xcodeVersion: String, macOSVersion: String, deviceIdentifier: String,
                    processingProfile: String) {
            self.runID = runID
            self.corpusRevision = corpusRevision
            self.modelIdentifier = modelIdentifier
            self.xcodeVersion = xcodeVersion
            self.macOSVersion = macOSVersion
            self.deviceIdentifier = deviceIdentifier
            self.processingProfile = processingProfile
        }
    }

    public struct Report: Codable, Equatable, Sendable {
        public let schemaVersion: Int
        public let corpusRevision: String
        public let run: RunMetadata?
        public let metrics: [MetricResult]

        public init(schemaVersion: Int = EvaluationContract.currentSchemaVersion,
                    corpusRevision: String, run: RunMetadata?, metrics: [MetricResult]) {
            self.schemaVersion = schemaVersion
            self.corpusRevision = corpusRevision
            self.run = run
            self.metrics = metrics
        }
    }

    public enum ValidationError: Error, Equatable, CustomStringConvertible, Sendable {
        case schemaVersionUnsupported(Int)
        case emptyField(String)
        case duplicateID(String)
        case productDocumentReference(String)
        case consentNotSeparated
        case missingAdversarialTag(String)
        case measuredValueWithoutRun(String)
        case unavailableMetricHasValue(String)
        case measuredMetricMissingValue(String)
        case missingUnavailableReason(String)
        case corpusRevisionMismatch

        public var description: String {
            switch self {
            case .schemaVersionUnsupported(let value): return "Unsupported schema version: \(value)"
            case .emptyField(let field): return "Empty required field: \(field)"
            case .duplicateID(let id): return "Duplicate identifier: \(id)"
            case .productDocumentReference(let value): return "Product document reference is not allowed: \(value)"
            case .consentNotSeparated: return "Consent must explicitly exclude product documents"
            case .missingAdversarialTag(let tag): return "Required adversarial tag is missing: \(tag)"
            case .measuredValueWithoutRun(let id): return "Measured metric has no run metadata: \(id)"
            case .unavailableMetricHasValue(let id): return "Unavailable metric must not have a value: \(id)"
            case .measuredMetricMissingValue(let id): return "Measured metric must have a value: \(id)"
            case .missingUnavailableReason(let id): return "Unavailable metric needs a reason: \(id)"
            case .corpusRevisionMismatch: return "Report and run corpus revisions do not match"
            }
        }
    }

    public static func validate(_ manifest: CorpusManifest) -> [ValidationError] {
        var errors: [ValidationError] = []
        if manifest.schemaVersion != currentSchemaVersion { errors.append(.schemaVersionUnsupported(manifest.schemaVersion)) }
        for (name, value) in [("corpusID", manifest.corpusID), ("revision", manifest.revision),
                              ("consentVersion", manifest.consent.consentVersion),
                              ("purpose", manifest.consent.purpose),
                              ("collectionScope", manifest.consent.collectionScope),
                              ("retentionPolicy", manifest.consent.retentionPolicy),
                              ("withdrawalProcess", manifest.consent.withdrawalProcess)] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyField(name))
        }
        if !manifest.consent.productDocumentsExcluded { errors.append(.consentNotSeparated) }
        var ids = Set<String>()
        var tags = Set<String>()
        for sample in manifest.samples {
            if !ids.insert(sample.id).inserted { errors.append(.duplicateID(sample.id)) }
            if sample.id.contains("/") || sample.sourceReference.contains("/Users/") || sample.sourceReference.contains("product") {
                errors.append(.productDocumentReference(sample.id))
            }
            tags.formUnion(sample.adversarialTags)
        }
        for tag in requiredAdversarialTags where !tags.contains(tag) { errors.append(.missingAdversarialTag(tag)) }
        return errors
    }

    public static func validate(_ report: Report, against manifest: CorpusManifest) -> [ValidationError] {
        var errors: [ValidationError] = []
        if report.schemaVersion != currentSchemaVersion { errors.append(.schemaVersionUnsupported(report.schemaVersion)) }
        if let run = report.run, run.corpusRevision != report.corpusRevision { errors.append(.corpusRevisionMismatch) }
        var ids = Set<String>()
        for metric in report.metrics {
            if !ids.insert(metric.metricID).inserted { errors.append(.duplicateID(metric.metricID)) }
            switch metric.status {
            case .unavailable:
                if metric.value != nil { errors.append(.unavailableMetricHasValue(metric.metricID)) }
                if metric.unavailableReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { errors.append(.missingUnavailableReason(metric.metricID)) }
            case .measured:
                if report.run == nil { errors.append(.measuredValueWithoutRun(metric.metricID)) }
                if metric.value == nil { errors.append(.measuredMetricMissingValue(metric.metricID)) }
            }
        }
        _ = manifest // Keeps the API explicit for future metric/corpus membership checks.
        return errors
    }
}
