import Foundation

/// Privacy-safe provenance for one generated summary. Prompts, source text,
/// and provider diagnostics are intentionally excluded from this record.
public struct AISummaryProvenance: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let sessionID: UUID
    public let requestID: UUID
    public let provider: String
    public let modelIdentifier: String
    public let generatedAt: Date
    public let summaryLength: SummaryLength
    public let context: IntelligenceContextMetadata
    public let citedPageBlockIDs: [GroundedSourceReference]

    public init(
        sessionID: UUID = UUID(),
        requestID: UUID = UUID(),
        provider: String,
        modelIdentifier: String,
        generatedAt: Date = Date(),
        summaryLength: SummaryLength,
        context: IntelligenceContextMetadata,
        citedPageBlockIDs: [GroundedSourceReference]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID
        self.requestID = requestID
        self.provider = provider
        self.modelIdentifier = modelIdentifier
        self.generatedAt = generatedAt
        self.summaryLength = summaryLength
        self.context = context
        self.citedPageBlockIDs = citedPageBlockIDs
    }
}
