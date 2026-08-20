import Foundation

public enum SourceType: String, Codable, Sendable {
    case pdf
    case image
    case screenshot
    case clipboard
    case sample
}

public enum ProcessingStatus: String, Codable, Sendable {
    case pending
    case processing
    case complete
    case partial
    case failed
}

public enum OCRStatus: String, Codable, Sendable {
    case pending
    case processing
    case complete
    case failed
}

public enum LayoutType: String, Codable, Sendable {
    case singleColumn
    case multiColumn
    case slide
    case form
    case mixed
    case unknown
}

public enum OCRProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case general = "General"
    case legal = "Legal"
    case academic = "Academic"
    case receipts = "Receipts"
    case slides = "Slides"

    public var id: String { rawValue }

    public init(settingsValue: String) {
        self = OCRProfile(rawValue: settingsValue) ?? .general
    }
}

public enum BlockType: String, Codable, Sendable {
    case heading
    case paragraph
    case list
    case table
    case figure
    case caption
    case footer
    case header
    case unknown
}

/// Semantic content roles are intentionally separate from the legacy
/// `BlockType` enum.  `BlockType` is still used by the existing editor and
/// exporters, while this richer vocabulary lets the analysis pipeline retain
/// distinctions such as footnotes and sidebars.  `unknown` is a first-class
/// result: uncertain OCR is never silently promoted to prose.
public enum ContentRole: String, Codable, Equatable, Sendable, CaseIterable {
    case heading
    case paragraph
    case list
    case table
    case figure
    case caption
    case header
    case footer
    case footnote
    case sidebar
    case unknown

    public init(legacyType: BlockType) {
        switch legacyType {
        case .heading: self = .heading
        case .paragraph: self = .paragraph
        case .list: self = .list
        case .table: self = .table
        case .figure: self = .figure
        case .caption: self = .caption
        case .header: self = .header
        case .footer: self = .footer
        case .unknown: self = .unknown
        }
    }

    public var legacyType: BlockType {
        switch self {
        case .heading: return .heading
        case .paragraph: return .paragraph
        case .list: return .list
        case .table: return .table
        case .figure: return .figure
        case .caption: return .caption
        case .header, .footnote: return .footer
        case .footer: return .footer
        case .sidebar: return .paragraph
        case .unknown: return .unknown
        }
    }
}

public enum BlockSource: String, Codable, Sendable {
    case visionOCR = "vision-ocr"
    case embeddedPDF = "embedded-pdf"
    case receiptProfile = "receipt-profile"
    case userEdited = "user-edited"

    public var metadataValue: String { rawValue }
}

public enum ProvenanceSource: String, Codable, Sendable {
    case embeddedPDF
    case visionOCR
    case userEdit
    case appleIntelligence
    case heuristic
}

/// Typed lineage for a derived text block. It records where the block came
/// from without copying its source text into a second metadata field.
public struct BlockProvenance: Codable, Equatable, Sendable {
    public var source: ProvenanceSource
    public var pageNumber: Int
    public var bounds: BoundingBox?
    public var confidence: Double?
    public var createdAt: Date
    public var parentBlockID: UUID?
    public var engine: String?

    public init(
        source: ProvenanceSource,
        pageNumber: Int,
        bounds: BoundingBox? = nil,
        confidence: Double? = nil,
        createdAt: Date = Date(),
        parentBlockID: UUID? = nil,
        engine: String? = nil
    ) {
        self.source = source
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.confidence = confidence
        self.createdAt = createdAt
        self.parentBlockID = parentBlockID
        self.engine = engine
    }
}

public extension TextBlock {
    var blockSource: BlockSource? {
        guard let raw = metadata["source"] else { return nil }
        return BlockSource(rawValue: raw)
    }
}

public enum ChartType: String, Codable, Sendable {
    case bar
    case line
    case pie
    case scatter
    case flowchart
    case unknown
}

public struct PageSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct BoundingBox: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var midX: Double { x + width / 2 }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var midY: Double { y + height / 2 }
    public var maxY: Double { y + height }
}

public struct OCRObservationRecord: Codable, Equatable, Sendable {
    public var transcript: String
    public var confidence: Double
    /// Vision-normalized coordinates (origin at the lower-left).
    public var normalizedBounds: BoundingBox
    public var engine: String
    public var kind: String

    public init(transcript: String, confidence: Double, normalizedBounds: BoundingBox, engine: String, kind: String = "text") {
        self.transcript = transcript
        self.confidence = confidence
        self.normalizedBounds = normalizedBounds
        self.engine = engine
        self.kind = kind
    }
}

public struct ReadingOrderEvidence: Codable, Equatable, Sendable {
    public var strategy: String
    public var confidence: Double
    public var pageNumber: Int

    public init(strategy: String, confidence: Double, pageNumber: Int) {
        self.strategy = strategy
        self.confidence = confidence
        self.pageNumber = pageNumber
    }
}

public struct TextBlock: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var type: BlockType
    public var text: String
    public var bounds: BoundingBox
    public var confidence: Double
    public var readingOrderIndex: Int
    public var metadata: [String: String]
    public var provenance: BlockProvenance?
    /// The first extracted text, retained for an explicit raw-OCR diff.
    /// Existing documents decode this as nil and remain fully readable.
    public var originalText: String?
    /// Raw, privacy-sensitive OCR observation metadata retained for audit and
    /// layout regression; this stores no Vision framework object.
    public var rawObservation: OCRObservationRecord?
    public var readingOrderEvidence: ReadingOrderEvidence?
    /// Rich semantic role assigned by layout analysis or an explicit user
    /// edit. Optional keeps documents written before role modeling readable;
    /// use `resolvedContentRole` at consumption boundaries.
    public var contentRole: ContentRole?

    public var resolvedContentRole: ContentRole {
        contentRole ?? ContentRole(legacyType: type)
    }

    public var hasTextEdit: Bool {
        guard let originalText else { return false }
        return originalText != text
    }

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        type: BlockType,
        text: String,
        bounds: BoundingBox,
        confidence: Double,
        readingOrderIndex: Int = 0,
        metadata: [String: String] = [:],
        provenance: BlockProvenance? = nil,
        originalText: String? = nil,
        rawObservation: OCRObservationRecord? = nil,
        readingOrderEvidence: ReadingOrderEvidence? = nil,
        contentRole: ContentRole? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.type = type
        self.text = text
        self.bounds = bounds
        self.confidence = confidence
        self.readingOrderIndex = readingOrderIndex
        self.metadata = metadata
        self.provenance = provenance
        self.originalText = originalText
        self.rawObservation = rawObservation
        self.readingOrderEvidence = readingOrderEvidence
        self.contentRole = contentRole
    }
}

public struct TableRegion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var bounds: BoundingBox
    public var rows: [[String]]
    public var explanation: String
    public var confidence: Double
    public var provenance: BlockProvenance?
    /// Zero-based row indexes explicitly assigned as column headers.
    public var columnHeaderRows: [Int]
    /// Zero-based column indexes explicitly assigned as row headers.
    public var rowHeaderColumns: [Int]

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        bounds: BoundingBox,
        rows: [[String]],
        explanation: String = "",
        confidence: Double,
        provenance: BlockProvenance? = nil,
        columnHeaderRows: [Int] = [],
        rowHeaderColumns: [Int] = []
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.rows = rows
        self.explanation = explanation
        self.confidence = confidence
        self.provenance = provenance
        self.columnHeaderRows = columnHeaderRows
        self.rowHeaderColumns = rowHeaderColumns
    }

    private enum CodingKeys: String, CodingKey {
        case id, pageNumber, bounds, rows, explanation, confidence, provenance, columnHeaderRows, rowHeaderColumns
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        pageNumber = try values.decode(Int.self, forKey: .pageNumber)
        bounds = try values.decode(BoundingBox.self, forKey: .bounds)
        rows = try values.decode([[String]].self, forKey: .rows)
        explanation = try values.decode(String.self, forKey: .explanation)
        confidence = try values.decode(Double.self, forKey: .confidence)
        provenance = try values.decodeIfPresent(BlockProvenance.self, forKey: .provenance)
        columnHeaderRows = try values.decodeIfPresent([Int].self, forKey: .columnHeaderRows) ?? []
        rowHeaderColumns = try values.decodeIfPresent([Int].self, forKey: .rowHeaderColumns) ?? []
    }
}

public struct FigureRegion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var bounds: BoundingBox
    public var chartType: ChartType
    public var visibleText: String
    public var description: String
    public var confidence: Double
    public var uncertaintyNotes: [String]
    public var provenance: BlockProvenance?

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        bounds: BoundingBox,
        chartType: ChartType,
        visibleText: String,
        description: String,
        confidence: Double,
        uncertaintyNotes: [String] = [],
        provenance: BlockProvenance? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.chartType = chartType
        self.visibleText = visibleText
        self.description = description
        self.confidence = confidence
        self.uncertaintyNotes = uncertaintyNotes
        self.provenance = provenance
    }
}

public struct ReaderLink: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var bounds: BoundingBox
    public var label: String?
    public var url: URL?
    public var targetPageNumber: Int?

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        bounds: BoundingBox,
        label: String? = nil,
        url: URL? = nil,
        targetPageNumber: Int? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.label = label
        self.url = url
        self.targetPageNumber = targetPageNumber
    }
}

public struct ReaderAnnotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var type: String
    public var bounds: BoundingBox
    public var contents: String?
    public var fieldName: String?
    public var value: String?

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        type: String,
        bounds: BoundingBox,
        contents: String? = nil,
        fieldName: String? = nil,
        value: String? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.type = type
        self.bounds = bounds
        self.contents = contents
        self.fieldName = fieldName
        self.value = value
    }
}

public struct DocumentTextPosition: Codable, Equatable, Sendable {
    public var characterIndex: Int
    public var bounds: BoundingBox

    public init(characterIndex: Int, bounds: BoundingBox) {
        self.characterIndex = characterIndex
        self.bounds = bounds
    }
}

public struct ReaderPage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var size: PageSize
    public var thumbnailData: Data?
    public var ocrStatus: OCRStatus
    public var layoutType: LayoutType
    public var blocks: [TextBlock]
    public var tables: [TableRegion]
    public var figures: [FigureRegion]
    public var warning: String?
    /// Human-facing PDF page label (for example, "iv" or "A-1").
    public var pageLabel: String?
    public var links: [ReaderLink]
    public var annotations: [ReaderAnnotation]
    public var textPositions: [DocumentTextPosition]

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        size: PageSize,
        thumbnailData: Data? = nil,
        ocrStatus: OCRStatus = .pending,
        layoutType: LayoutType = .unknown,
        blocks: [TextBlock],
        tables: [TableRegion] = [],
        figures: [FigureRegion] = [],
        warning: String? = nil,
        pageLabel: String? = nil,
        links: [ReaderLink] = [],
        annotations: [ReaderAnnotation] = [],
        textPositions: [DocumentTextPosition] = []
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.size = size
        self.thumbnailData = thumbnailData
        self.ocrStatus = ocrStatus
        self.layoutType = layoutType
        self.blocks = blocks
        self.tables = tables
        self.figures = figures
        self.warning = warning
        self.pageLabel = pageLabel
        self.links = links
        self.annotations = annotations
        self.textPositions = textPositions
    }

    private enum CodingKeys: String, CodingKey {
        case id, pageNumber, size, thumbnailData, ocrStatus, layoutType, blocks, tables, figures, warning, pageLabel, links, annotations, textPositions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        pageNumber = try values.decode(Int.self, forKey: .pageNumber)
        size = try values.decode(PageSize.self, forKey: .size)
        thumbnailData = try values.decodeIfPresent(Data.self, forKey: .thumbnailData)
        ocrStatus = try values.decode(OCRStatus.self, forKey: .ocrStatus)
        layoutType = try values.decode(LayoutType.self, forKey: .layoutType)
        blocks = try values.decode([TextBlock].self, forKey: .blocks)
        tables = try values.decode([TableRegion].self, forKey: .tables)
        figures = try values.decode([FigureRegion].self, forKey: .figures)
        warning = try values.decodeIfPresent(String.self, forKey: .warning)
        pageLabel = try values.decodeIfPresent(String.self, forKey: .pageLabel)
        links = try values.decodeIfPresent([ReaderLink].self, forKey: .links) ?? []
        annotations = try values.decodeIfPresent([ReaderAnnotation].self, forKey: .annotations) ?? []
        textPositions = try values.decodeIfPresent([DocumentTextPosition].self, forKey: .textPositions) ?? []
    }
}

public struct OutlineItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var pageNumber: Int
    public var level: Int

    public init(id: UUID = UUID(), title: String, pageNumber: Int, level: Int = 1) {
        self.id = id
        self.title = title
        self.pageNumber = pageNumber
        self.level = level
    }
}

public struct ReaderDocument: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var sourceType: SourceType
    public var sourceURL: URL?
    public var createdAt: Date
    public var language: String?
    public var processingStatus: ProcessingStatus
    public var pages: [ReaderPage]
    public var outline: [OutlineItem]
    public var summary: String
    /// Privacy-safe metadata for the latest generated summary. Prompts and
    /// provider response diagnostics are deliberately not retained.
    public var summaryProvenance: AISummaryProvenance?
    /// Non-text PDF metadata retained for provenance and downstream exports.
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        title: String,
        sourceType: SourceType,
        sourceURL: URL? = nil,
        createdAt: Date = Date(),
        language: String? = nil,
        processingStatus: ProcessingStatus = .pending,
        pages: [ReaderPage],
        outline: [OutlineItem] = [],
        summary: String = "",
        summaryProvenance: AISummaryProvenance? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.language = language
        self.processingStatus = processingStatus
        self.pages = pages
        self.outline = outline
        self.summary = summary
        self.summaryProvenance = summaryProvenance
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, sourceType, sourceURL, createdAt, language, processingStatus, pages, outline, summary, summaryProvenance, metadata
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        sourceType = try values.decode(SourceType.self, forKey: .sourceType)
        sourceURL = try values.decodeIfPresent(URL.self, forKey: .sourceURL)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        language = try values.decodeIfPresent(String.self, forKey: .language)
        processingStatus = try values.decode(ProcessingStatus.self, forKey: .processingStatus)
        pages = try values.decode([ReaderPage].self, forKey: .pages)
        outline = try values.decode([OutlineItem].self, forKey: .outline)
        summary = try values.decode(String.self, forKey: .summary)
        summaryProvenance = try values.decodeIfPresent(AISummaryProvenance.self, forKey: .summaryProvenance)
        metadata = try values.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    public var pageCount: Int { pages.count }
    public var allBlocks: [TextBlock] { pages.flatMap(\.blocks).sorted { $0.pageNumber == $1.pageNumber ? $0.readingOrderIndex < $1.readingOrderIndex : $0.pageNumber < $1.pageNumber } }
}

public struct ExportOptions: Equatable, Sendable {
    public var includeHeadings: Bool
    public var includeTables: Bool
    public var includeFigures: Bool
    public var includePageReferences: Bool
    public var includeConfidenceNotes: Bool
    public var includeHeadersAndFooters: Bool
    public var redactSourceURL: Bool
    public var redactTextSnippets: Bool
    public var includeProvenance: Bool

    public static let full = ExportOptions(
        includeHeadings: true,
        includeTables: true,
        includeFigures: true,
        includePageReferences: true,
        includeConfidenceNotes: true,
        includeHeadersAndFooters: true,
        redactSourceURL: false,
        redactTextSnippets: false,
        includeProvenance: true
    )

    public static let anonymous = ExportOptions(
        includeHeadings: true,
        includeTables: true,
        includeFigures: true,
        includePageReferences: true,
        includeConfidenceNotes: true,
        includeHeadersAndFooters: true,
        redactSourceURL: true,
        redactTextSnippets: true,
        includeProvenance: true
    )

    public init(
        includeHeadings: Bool,
        includeTables: Bool,
        includeFigures: Bool,
        includePageReferences: Bool,
        includeConfidenceNotes: Bool,
        includeHeadersAndFooters: Bool = true,
        redactSourceURL: Bool = false,
        redactTextSnippets: Bool = false,
        includeProvenance: Bool = true
    ) {
        self.includeHeadings = includeHeadings
        self.includeTables = includeTables
        self.includeFigures = includeFigures
        self.includePageReferences = includePageReferences
        self.includeConfidenceNotes = includeConfidenceNotes
        self.includeHeadersAndFooters = includeHeadersAndFooters
        self.redactSourceURL = redactSourceURL
        self.redactTextSnippets = redactTextSnippets
        self.includeProvenance = includeProvenance
    }
}

public enum SummaryLength: String, CaseIterable, Identifiable, Codable, Sendable {
    case short = "30 seconds"
    case medium = "2 minutes"
    case detailed = "Detailed walkthrough"

    public var id: String { rawValue }
}
