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

public struct TextBlock: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var type: BlockType
    public var text: String
    public var bounds: BoundingBox
    public var confidence: Double
    public var readingOrderIndex: Int
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        type: BlockType,
        text: String,
        bounds: BoundingBox,
        confidence: Double,
        readingOrderIndex: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.type = type
        self.text = text
        self.bounds = bounds
        self.confidence = confidence
        self.readingOrderIndex = readingOrderIndex
        self.metadata = metadata
    }
}

public struct TableRegion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageNumber: Int
    public var bounds: BoundingBox
    public var rows: [[String]]
    public var explanation: String
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        bounds: BoundingBox,
        rows: [[String]],
        explanation: String = "",
        confidence: Double
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.rows = rows
        self.explanation = explanation
        self.confidence = confidence
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

    public init(
        id: UUID = UUID(),
        pageNumber: Int,
        bounds: BoundingBox,
        chartType: ChartType,
        visibleText: String,
        description: String,
        confidence: Double,
        uncertaintyNotes: [String] = []
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.chartType = chartType
        self.visibleText = visibleText
        self.description = description
        self.confidence = confidence
        self.uncertaintyNotes = uncertaintyNotes
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
        warning: String? = nil
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
        summary: String = ""
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

    public static let full = ExportOptions(
        includeHeadings: true,
        includeTables: true,
        includeFigures: true,
        includePageReferences: true,
        includeConfidenceNotes: true,
        includeHeadersAndFooters: true
    )

    public init(
        includeHeadings: Bool,
        includeTables: Bool,
        includeFigures: Bool,
        includePageReferences: Bool,
        includeConfidenceNotes: Bool,
        includeHeadersAndFooters: Bool = true
    ) {
        self.includeHeadings = includeHeadings
        self.includeTables = includeTables
        self.includeFigures = includeFigures
        self.includePageReferences = includePageReferences
        self.includeConfidenceNotes = includeConfidenceNotes
        self.includeHeadersAndFooters = includeHeadersAndFooters
    }
}

public enum SummaryLength: String, CaseIterable, Identifiable, Sendable {
    case short = "30 seconds"
    case medium = "2 minutes"
    case detailed = "Detailed walkthrough"

    public var id: String { rawValue }
}
