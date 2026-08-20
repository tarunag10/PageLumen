import Foundation

/// The kind of user-visible content that an on-device model produced.  This
/// vocabulary is deliberately small: it lets exports and review tools tell a
/// generated description from a generated document summary without retaining
/// prompts or model output in provenance.
public enum AIGeneratedContentKind: String, Codable, Equatable, Sendable {
    case summary
    case description
}

/// Privacy-safe, block-level lineage for content that was explicitly accepted
/// from an AI draft.  Parent locations are stable identifiers only; source
/// excerpts, prompts, responses, and provider diagnostics are never stored.
public struct AIBlockLineage: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let contentKind: AIGeneratedContentKind
    public let sessionID: UUID
    public let requestID: UUID
    public let provider: String
    public let modelIdentifier: String
    public let generatedAt: Date
    public let parentSources: [GroundedSourceReference]

    public init(
        contentKind: AIGeneratedContentKind,
        sessionID: UUID,
        requestID: UUID,
        provider: String,
        modelIdentifier: String,
        generatedAt: Date,
        parentSources: [GroundedSourceReference]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.contentKind = contentKind
        self.sessionID = sessionID
        self.requestID = requestID
        self.provider = provider
        self.modelIdentifier = modelIdentifier
        self.generatedAt = generatedAt
        self.parentSources = parentSources
    }

    public init?(contentKind: AIGeneratedContentKind, provenance: AISummaryProvenance) {
        self.init(
            contentKind: contentKind,
            sessionID: provenance.sessionID,
            requestID: provenance.requestID,
            provider: provenance.provider,
            modelIdentifier: provenance.modelIdentifier,
            generatedAt: provenance.generatedAt,
            parentSources: provenance.citedPageBlockIDs
        )
    }
}

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
