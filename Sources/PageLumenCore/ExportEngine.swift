import AppKit
import Foundation

public enum ExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case markdown = "Markdown"
    case text = "TXT"
    case html = "HTML"
    case taggedHTML = "Tagged HTML"
    /// A selectable text PDF. This is not a claim of PDF/UA conformance.
    case pdf = "Readable PDF"
    case csv = "CSV"
    case json = "JSON"
    case accessibilityReport = "Accessibility Report"
    case audio = "Audio"
    case docx = "DOCX"
    case translated = "Translate and Export Markdown"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .text: return "txt"
        case .html, .taggedHTML: return "html"
        case .pdf: return "pdf"
        case .csv: return "csv"
        case .json: return "json"
        case .accessibilityReport: return "md"
        case .audio: return "m4a"
        case .docx: return "docx"
        case .translated: return "md"
        }
    }
}

public enum ExportValidationStatus: String, Codable, Equatable, Sendable {
    case ready
    case reviewRequired
    case unavailable
}

public enum ExportValidationFindingSeverity: String, Codable, Equatable, Sendable {
    case info
    case warning
    case blocker
}

/// Structured validation data for clients that should not parse display text.
/// The legacy `findings` strings remain on `ExportValidationResult` for
/// compatibility with the current UI and integrations.
public struct ExportValidationFinding: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var code: String
    public var severity: ExportValidationFindingSeverity
    public var pageNumber: Int?
    public var blockID: UUID?
    public var message: String
    public var recommendation: String

    public init(
        id: String? = nil,
        code: String,
        severity: ExportValidationFindingSeverity,
        pageNumber: Int? = nil,
        blockID: UUID? = nil,
        message: String,
        recommendation: String
    ) {
        self.code = code
        self.severity = severity
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.message = message
        self.recommendation = recommendation
        let page = pageNumber.map(String.init) ?? "document"
        let block = blockID?.uuidString ?? ""
        self.id = id ?? [code, page, block].joined(separator: ":")
    }
}

/// The capabilities and evidence behind an export format. Keeping this contract
/// in the core model prevents UI copy and export behaviour from drifting apart.
public struct ExportCapability: Codable, Equatable, Sendable {
    public var format: ExportFormat
    public var status: ExportValidationStatus
    public var retainsStructure: Bool
    public var retainsTables: Bool
    public var retainsFigureDescriptions: Bool
    public var includesSourceReferences: Bool
    public var validationNotes: [String]

    public init(
        format: ExportFormat,
        status: ExportValidationStatus,
        retainsStructure: Bool,
        retainsTables: Bool,
        retainsFigureDescriptions: Bool,
        includesSourceReferences: Bool,
        validationNotes: [String]
    ) {
        self.format = format
        self.status = status
        self.retainsStructure = retainsStructure
        self.retainsTables = retainsTables
        self.retainsFigureDescriptions = retainsFigureDescriptions
        self.includesSourceReferences = includesSourceReferences
        self.validationNotes = validationNotes
    }
}

public struct ExportValidationResult: Codable, Equatable, Sendable {
    public var format: ExportFormat
    public var status: ExportValidationStatus
    public var capability: ExportCapability
    public var findings: [String]
    public var structuredFindings: [ExportValidationFinding]

    public init(
        format: ExportFormat,
        status: ExportValidationStatus,
        capability: ExportCapability,
        findings: [String],
        structuredFindings: [ExportValidationFinding] = []
    ) {
        self.format = format
        self.status = status
        self.capability = capability
        self.findings = findings
        self.structuredFindings = structuredFindings
    }

    public var canExport: Bool { status != .unavailable }

    /// Deterministic human-readable validation output for logs and UI.
    public var report: String {
        var lines = ["\(format.rawValue) export validation", "Status: \(status.rawValue)"]
        if structuredFindings.isEmpty {
            lines.append("No machine-readable findings.")
        } else {
            for finding in structuredFindings {
                let location = finding.pageNumber.map { "Page \($0): " } ?? ""
                lines.append("- [\(finding.severity.rawValue)] \(finding.code): \(location)\(finding.message)")
                if !finding.recommendation.isEmpty {
                    lines.append("  Recommendation: \(finding.recommendation)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum AccessibilityFindingKind: String, Codable, Equatable, Sendable {
    case missingLanguage
    case missingHeadings
    case emptyHeading
    case lowConfidenceText
    case missingFigureDescription
    case tableNeedsHeaderReview
}

public enum AccessibilitySeverity: String, Codable, Equatable, Sendable {
    case blocker = "Needs fix"
    case warning = "Review"
    case passed = "Ready"
}

public struct AccessibilityFinding: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: AccessibilityFindingKind
    public var severity: AccessibilitySeverity
    public var pageNumber: Int?
    public var message: String
    public var recommendation: String

    public init(
        id: UUID = UUID(),
        kind: AccessibilityFindingKind,
        severity: AccessibilitySeverity,
        pageNumber: Int? = nil,
        message: String,
        recommendation: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.pageNumber = pageNumber
        self.message = message
        self.recommendation = recommendation
    }
}

public struct AccessibilityAudit: Codable, Equatable, Sendable {
    public var findings: [AccessibilityFinding]

    public init(findings: [AccessibilityFinding]) {
        self.findings = findings
    }

    public var isReadyForTaggedExport: Bool {
        !findings.contains { $0.severity == .blocker }
    }

    public var blockerCount: Int {
        findings.filter { $0.severity == .blocker }.count
    }

    public var warningCount: Int {
        findings.filter { $0.severity == .warning }.count
    }

    public var summary: String {
        if findings.isEmpty {
            return "Ready for tagged export. No structural issues were found by PageLumen's automated checks."
        }
        return "\(blockerCount) needs-fix item\(blockerCount == 1 ? "" : "s"), \(warningCount) review item\(warningCount == 1 ? "" : "s")."
    }
}

public struct AccessibilityAuditor: Sendable {
    public init() {}

    public func audit(document: ReaderDocument, options: ExportOptions) -> AccessibilityAudit {
        var findings: [AccessibilityFinding] = []

        if document.language?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            findings.append(AccessibilityFinding(
                kind: .missingLanguage,
                severity: .blocker,
                message: "Document language is not set.",
                recommendation: "Set a document language before producing a tagged accessibility export."
            ))
        }

        let exportableBlocks = document.pages.flatMap { page in
            DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters)
        }

        if options.includeHeadings, !exportableBlocks.contains(where: { $0.type == .heading }) {
            findings.append(AccessibilityFinding(
                kind: .missingHeadings,
                severity: .warning,
                message: "No headings were detected.",
                recommendation: "Review the reading order and promote section titles to headings where appropriate."
            ))
        }

        for page in document.pages {
            let blocks = DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters)
            for block in blocks {
                let trimmedText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)

                if options.includeHeadings, block.type == .heading, trimmedText.isEmpty {
                    findings.append(AccessibilityFinding(
                        kind: .emptyHeading,
                        severity: .blocker,
                        pageNumber: page.pageNumber,
                        message: "A heading is empty.",
                        recommendation: "Remove the empty heading or replace it with the visible section title."
                    ))
                }

                if block.confidence < 0.7, !trimmedText.isEmpty {
                    let preview: String
                    if options.redactTextSnippets {
                        preview = "<text redacted>"
                    } else {
                        preview = String(trimmedText.prefix(80))
                    }
                    findings.append(AccessibilityFinding(
                        kind: .lowConfidenceText,
                        severity: .warning,
                        pageNumber: page.pageNumber,
                        message: "OCR confidence is \(Int(block.confidence * 100))% for: \(preview)",
                        recommendation: "Review this text in Step 3 before exporting."
                    ))
                }

                if options.includeFigures, block.type == .figure {
                    let description = page.figures.first(where: { $0.bounds == block.bounds })?.description ?? block.text
                    if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        findings.append(AccessibilityFinding(
                            kind: .missingFigureDescription,
                            severity: .blocker,
                            pageNumber: page.pageNumber,
                            message: "A figure has no description.",
                            recommendation: "Add a concise figure description so assistive technology has useful alternate text."
                        ))
                    }
                }
            }

            if options.includeTables {
                for table in page.tables {
                    let header = table.rows.first ?? []
                    if table.rows.count < 2 || header.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        findings.append(AccessibilityFinding(
                            kind: .tableNeedsHeaderReview,
                            severity: .warning,
                            pageNumber: page.pageNumber,
                            message: "A table may be missing usable column headers.",
                            recommendation: "Review the first row and make sure it describes each column."
                        ))
                    }
                }
            }
        }

        return AccessibilityAudit(findings: findings)
    }
}

public struct ExportEngine: Sendable {
    /// The additive JSON export contract. The document fields remain at the
    /// root so consumers of the original unversioned export can continue to
    /// read the fields they already know. New consumers should inspect the
    /// `schemaVersion` and `export` envelope before interpreting metadata.
    public static let jsonSchemaVersion = "1"

    public init() {}

    public func capability(for format: ExportFormat) -> ExportCapability {
        switch format {
        case .markdown:
            return ExportCapability(format: format, status: .ready, retainsStructure: true, retainsTables: true, retainsFigureDescriptions: true, includesSourceReferences: true, validationNotes: ["Markdown is a portable, reviewable representation; rendered styling is controlled by the consumer."])
        case .text:
            return ExportCapability(format: format, status: .ready, retainsStructure: false, retainsTables: false, retainsFigureDescriptions: false, includesSourceReferences: true, validationNotes: ["Plain text intentionally discards semantic structure and table relationships."])
        case .html, .taggedHTML:
            return ExportCapability(format: format, status: .reviewRequired, retainsStructure: true, retainsTables: true, retainsFigureDescriptions: true, includesSourceReferences: true, validationNotes: ["Validate heading hierarchy, language, table headers, links, and figure descriptions before publishing."])
        case .pdf:
            return ExportCapability(format: format, status: .reviewRequired, retainsStructure: false, retainsTables: false, retainsFigureDescriptions: false, includesSourceReferences: true, validationNotes: ["Readable/selectable text PDF; PDF/UA conformance and tagging are not asserted."])
        case .csv:
            return ExportCapability(format: format, status: .ready, retainsStructure: false, retainsTables: true, retainsFigureDescriptions: false, includesSourceReferences: true, validationNotes: ["CSV contains table cells only and does not preserve document layout."])
        case .json:
            return ExportCapability(format: format, status: .ready, retainsStructure: true, retainsTables: true, retainsFigureDescriptions: true, includesSourceReferences: true, validationNotes: ["JSON is the versioned machine-readable representation of the reviewed document."])
        case .accessibilityReport:
            return ExportCapability(format: format, status: .ready, retainsStructure: false, retainsTables: false, retainsFigureDescriptions: false, includesSourceReferences: true, validationNotes: ["Report contains automated findings only; manual accessibility review remains required."])
        case .audio:
            return ExportCapability(format: format, status: .reviewRequired, retainsStructure: false, retainsTables: false, retainsFigureDescriptions: false, includesSourceReferences: false, validationNotes: ["Audio output is generated by the app-shell speech service and is not represented by core export data."])
        case .docx:
            return ExportCapability(format: format, status: .reviewRequired, retainsStructure: true, retainsTables: true, retainsFigureDescriptions: true, includesSourceReferences: true, validationNotes: ["DOCX is an Office Open XML package; open the generated archive with an independent consumer before delivery."])
        case .translated:
            return ExportCapability(format: format, status: .unavailable, retainsStructure: false, retainsTables: false, retainsFigureDescriptions: false, includesSourceReferences: false, validationNotes: ["Translation requires an available Translation framework provider and is not an ExportEngine operation."])
        }
    }

    public func validate(document: ReaderDocument, format: ExportFormat, options: ExportOptions) -> ExportValidationResult {
        let capability = capability(for: format)
        guard capability.status != .unavailable else {
            return ExportValidationResult(
                format: format,
                status: .unavailable,
                capability: capability,
                findings: capability.validationNotes,
                structuredFindings: capabilityFindings(for: format, capability: capability)
            )
        }

        var findings = capability.validationNotes
        var structuredFindings = capabilityFindings(for: format, capability: capability)
        if format == .taggedHTML || format == .html || format == .pdf || format == .docx {
            let audit = AccessibilityAuditor().audit(document: document, options: options)
            findings.append(contentsOf: audit.findings.map { finding in
                let page = finding.pageNumber.map { "Page \($0): " } ?? ""
                return "[\(finding.severity.rawValue)] \(page)\(finding.message)"
            })
            structuredFindings.append(contentsOf: audit.findings.map { finding in
                ExportValidationFinding(
                    code: finding.kind.rawValue,
                    severity: exportSeverity(for: finding.severity),
                    pageNumber: finding.pageNumber,
                    message: finding.message,
                    recommendation: finding.recommendation
                )
            })
            // A blocker is a hard stop for accessibility-sensitive formats. The
            // caller must resolve the finding before an artifact can be written;
            // warnings remain review-required but exportable.
            let unresolvedBlockers = DocumentEditing.reviewFindings(for: document).filter { !$0.isResolved && $0.severity == .blocker }
            findings.append(contentsOf: unresolvedBlockers.map { finding in
                "[Needs fix] Page \(finding.pageNumber): \(finding.title) — \(finding.detail)"
            })
            structuredFindings.append(contentsOf: unresolvedBlockers.map { finding in
                ExportValidationFinding(
                    code: finding.kind.rawValue,
                    severity: .blocker,
                    pageNumber: finding.pageNumber,
                    blockID: finding.blockID,
                    message: "\(finding.title) — \(finding.detail)",
                    recommendation: "Resolve this review finding before exporting this format."
                )
            })
            let status: ExportValidationStatus = audit.isReadyForTaggedExport && unresolvedBlockers.isEmpty ? capability.status : .unavailable
            return ExportValidationResult(format: format, status: status, capability: capability, findings: findings, structuredFindings: structuredFindings)
        }
        return ExportValidationResult(format: format, status: capability.status, capability: capability, findings: findings, structuredFindings: structuredFindings)
    }

    private func capabilityFindings(for format: ExportFormat, capability: ExportCapability) -> [ExportValidationFinding] {
        capability.validationNotes.enumerated().map { index, note in
            ExportValidationFinding(
                id: "capability-\(format.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))-\(index)",
                code: capability.status == .unavailable ? "format.unavailable" : "format.capability",
                severity: exportSeverity(for: capability.status),
                message: note,
                recommendation: capability.status == .reviewRequired ? "Complete the stated validation or human review before publishing this output." : ""
            )
        }
    }

    private func exportSeverity(for status: ExportValidationStatus) -> ExportValidationFindingSeverity {
        switch status {
        case .ready: return .info
        case .reviewRequired: return .warning
        case .unavailable: return .blocker
        }
    }

    private func exportSeverity(for severity: AccessibilitySeverity) -> ExportValidationFindingSeverity {
        switch severity {
        case .passed: return .info
        case .warning: return .warning
        case .blocker: return .blocker
        }
    }

    public func markdown(for document: ReaderDocument, options: ExportOptions) -> String {
        var lines = ["# \(markdownInline(document.title))", ""]
        for page in document.pages {
            if options.includePageReferences {
                lines.append("## Page \(page.pageNumber)")
                lines.append("")
            }

            for block in DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters) {
                switch block.type {
                case .heading where options.includeHeadings:
                    lines.append("### \(markdownInline(block.text))")
                case .table where options.includeTables:
                    if let table = page.tables.first(where: { $0.bounds == block.bounds }) {
                        lines.append(markdownTable(table.rows))
                        lines.append("")
                        lines.append("> \(markdownInline(table.explanation))")
                    } else {
                        lines.append(markdownInline(block.text))
                    }
                case .figure where options.includeFigures:
                    if let figure = page.figures.first(where: { $0.bounds == block.bounds }) {
                        lines.append("Figure: \(markdownInline(figure.description))")
                    } else {
                        lines.append("Figure: \(markdownInline(block.text))")
                    }
                default:
                    lines.append(markdownInline(block.text))
                }

                if options.includeConfidenceNotes, block.confidence < 0.7 {
                    lines.append("_Confidence: \(Int(block.confidence * 100))%. Review recommended._")
                }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    public func plainText(for document: ReaderDocument, options: ExportOptions) -> String {
        document.pages.map { page in
            var lines: [String] = []
            if options.includePageReferences {
                lines.append("Page \(page.pageNumber)")
                lines.append(String(repeating: "-", count: 12))
            }
            lines.append(contentsOf: DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters).map(\.text))
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    public func html(for document: ReaderDocument, options: ExportOptions) -> String {
        var body = ["<!doctype html>", "<html lang=\"\(document.language ?? "en")\">", "<head>", "<meta charset=\"utf-8\">", "<title>\(escape(document.title))</title>", "</head>", "<body>", "<main>", "<h1>\(escape(document.title))</h1>"]

        for page in document.pages {
            if options.includePageReferences {
                body.append("<section aria-label=\"Page \(page.pageNumber)\">")
                body.append("<h2>Page \(page.pageNumber)</h2>")
            }

            for block in DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters) {
                switch block.type {
                case .heading where options.includeHeadings:
                    body.append("<h3>\(escape(block.text))</h3>")
                case .table where options.includeTables:
                    if let table = page.tables.first(where: { $0.bounds == block.bounds }) {
                        body.append(htmlTable(table.rows, columnHeaderRows: table.columnHeaderRows, rowHeaderColumns: table.rowHeaderColumns))
                        body.append("<p><strong>Table note:</strong> \(escape(table.explanation))</p>")
                    } else {
                        body.append("<p>\(escape(block.text))</p>")
                    }
                case .figure where options.includeFigures:
                    let description = page.figures.first(where: { $0.bounds == block.bounds })?.description ?? block.text
                    body.append("<figure><figcaption>\(escape(description))</figcaption></figure>")
                default:
                    body.append("<p>\(escape(block.text))</p>")
                }
            }

            if options.includePageReferences {
                body.append("</section>")
            }
        }

        body.append(contentsOf: ["</main>", "</body>", "</html>"])
        return body.joined(separator: "\n")
    }

    public func taggedHTML(for document: ReaderDocument, options: ExportOptions) -> String {
        let language = document.language?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? document.language! : "en"
        let audit = AccessibilityAuditor().audit(document: document, options: options)
        var body = [
            "<!doctype html>",
            "<html lang=\"\(escape(language))\" data-pagelumen-export=\"tagged-html\">",
            "<head>",
            "<meta charset=\"utf-8\">",
            "<meta name=\"generator\" content=\"PageLumen\">",
            "<title>\(escape(document.title))</title>",
            "</head>",
            "<body>",
            "<a href=\"#content\">Skip to content</a>",
            "<main id=\"content\">",
            "<h1>\(escape(document.title))</h1>",
            "<aside aria-label=\"Accessibility export status\">",
            "<p>\(escape(audit.summary))</p>",
            "</aside>"
        ]

        for page in document.pages {
            if options.includePageReferences {
                body.append("<section aria-labelledby=\"page-\(page.pageNumber)-heading\" data-page=\"\(page.pageNumber)\">")
                body.append("<h2 id=\"page-\(page.pageNumber)-heading\">Page \(page.pageNumber)</h2>")
            } else {
                body.append("<section aria-label=\"Document content\" data-page=\"\(page.pageNumber)\">")
            }

            for block in DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters) {
                let blockID = "block-\(block.id.uuidString.lowercased())"
                switch block.type {
                case .heading where options.includeHeadings:
                    body.append("<h3 id=\"\(blockID)\" data-page=\"\(block.pageNumber)\">\(escape(block.text))</h3>")
                case .table where options.includeTables:
                    if let table = page.tables.first(where: { $0.bounds == block.bounds }) {
                        body.append(htmlTable(table.rows, pageNumber: page.pageNumber, blockID: blockID, columnHeaderRows: table.columnHeaderRows, rowHeaderColumns: table.rowHeaderColumns))
                        if !table.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            body.append("<p><strong>Table note:</strong> \(escape(table.explanation))</p>")
                        }
                    } else {
                        body.append("<p id=\"\(blockID)\" data-page=\"\(block.pageNumber)\" data-confidence=\"\(block.confidence)\">\(escape(block.text))</p>")
                    }
                case .figure where options.includeFigures:
                    let description = page.figures.first(where: { $0.bounds == block.bounds })?.description ?? block.text
                    body.append("<figure id=\"\(blockID)\" data-page=\"\(block.pageNumber)\"><div role=\"img\" aria-label=\"\(escape(description))\"></div><figcaption>\(escape(description))</figcaption></figure>")
                default:
                    body.append("<p id=\"\(blockID)\" data-page=\"\(block.pageNumber)\" data-confidence=\"\(block.confidence)\">\(escape(block.text))</p>")
                }

                if options.includeConfidenceNotes, block.confidence < 0.7 {
                    body.append("<p role=\"note\"><small>Confidence: \(Int(block.confidence * 100))%. Review recommended.</small></p>")
                }
            }

            body.append("</section>")
        }

        body.append(contentsOf: ["</main>", "</body>", "</html>"])
        return body.joined(separator: "\n")
    }

    public func pdfData(for document: ReaderDocument, options: ExportOptions) -> Data {
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        let textRect = pageRect.insetBy(dx: 48, dy: 48)
        let data = NSMutableData()
        let auxiliaryInfo: [String: Any] = [
            kCGPDFContextTitle as String: document.title,
            kCGPDFContextAuthor as String: "PageLumen",
            kCGPDFContextCreator as String: "PageLumen",
            kCGPDFContextSubject as String: "Document extracted with PageLumen"
        ]
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, auxiliaryInfo as CFDictionary) else {
            return Data()
        }

        let elements = pdfElements(for: document, options: options)
        var cursorY = textRect.minY

        func beginPage() {
            context.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary)
            context.saveGState()
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            cursorY = textRect.minY
        }

        func endPage() {
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()
        }

        beginPage()
        for element in elements {
            let height = element.height(constrainedTo: textRect.width)
            if cursorY > textRect.minY, cursorY + height > textRect.maxY {
                endPage()
                beginPage()
            }

            element.draw(in: NSRect(x: textRect.minX, y: cursorY, width: textRect.width, height: height))
            cursorY += height + element.spacingAfter
        }
        endPage()
        context.closePDF()
        return data as Data
    }

    public func data(for document: ReaderDocument, format: ExportFormat, options: ExportOptions) -> Data {
        switch format {
        case .markdown:
            return Data(markdown(for: document, options: options).utf8)
        case .text:
            return Data(plainText(for: document, options: options).utf8)
        case .html:
            return Data(html(for: document, options: options).utf8)
        case .taggedHTML:
            return Data(taggedHTML(for: document, options: options).utf8)
        case .pdf:
            return pdfData(for: document, options: options)
        case .csv:
            return Data(csv(for: document, options: options).utf8)
        case .json:
            return jsonData(for: document, options: options)
        case .accessibilityReport:
            return Data(accessibilityReport(for: document, options: options).utf8)
        case .audio:
            return Data(audioPlaceholder(for: document, options: options).utf8)
        case .docx:
            return Data(docxPlaceholder(for: document, options: options).utf8)
        case .translated:
            return Data()
        }
    }

    public func audioPlaceholder(for document: ReaderDocument, options: ExportOptions) -> String {
        let text = plainText(for: document, options: options)
        let preview = String(text.prefix(400))
        return "Audio export preview\nSource text length: \(text.count) characters\n\nFirst 400 characters:\n\(preview)\n\nThe full file will be written as an .m4a AAC file by AudioExportService."
    }

    public func docxPlaceholder(for document: ReaderDocument, options: ExportOptions) -> String {
        let text = plainText(for: document, options: options)
        let preview = String(text.prefix(400))
        return "DOCX export preview\nSource text length: \(text.count) characters\n\nFirst 400 characters:\n\(preview)\n\nThe full file will be written as a .docx (Office Open XML) file by DOCXWriter."
    }

    public func accessibilityReport(for document: ReaderDocument, options: ExportOptions) -> String {
        let audit = AccessibilityAuditor().audit(document: document, options: options)
        var lines = [
            "# Accessibility Report",
            "",
            "Document: \(document.title)",
            "Status: \(audit.isReadyForTaggedExport ? "Ready for tagged export" : "Needs review before tagged export")",
            "Summary: \(audit.summary)",
            ""
        ]

        if audit.findings.isEmpty {
            lines.append("No automated accessibility issues were found.")
        } else {
            for finding in audit.findings {
                let page = finding.pageNumber.map { "Page \($0): " } ?? ""
                lines.append("- [\(finding.severity.rawValue)] \(page)\(finding.message)")
                lines.append("  Recommendation: \(finding.recommendation)")
            }
        }

        return lines.joined(separator: "\n")
    }

    public func csv(for document: ReaderDocument, options: ExportOptions) -> String {
        var rows = ["Page,Table,Row,Column,Value"]

        for page in document.pages {
            for tableIndex in page.tables.indices {
                let table = page.tables[tableIndex]
                for rowIndex in table.rows.indices {
                    for columnIndex in table.rows[rowIndex].indices {
                        rows.append([
                            "\(page.pageNumber)",
                            "\(tableIndex + 1)",
                            "\(rowIndex + 1)",
                            "\(columnIndex + 1)",
                            csvEscape(table.rows[rowIndex][columnIndex])
                        ].joined(separator: ","))
                    }
                }
            }
        }

        return rows.joined(separator: "\n")
    }

    public func jsonData(for document: ReaderDocument, options: ExportOptions) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        var sanitized = sanitizedDocument(document, options: options)
        sanitized.pages = sanitized.pages.map { page in
            var copy = page
            copy.blocks = DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters)
            return copy
        }

        guard let documentData = try? encoder.encode(sanitized),
              var root = (try? JSONSerialization.jsonObject(with: documentData)) as? [String: Any] else {
            return Data("{}".utf8)
        }

        // Keep the original ReaderDocument properties at the root for
        // additive/backward-compatible consumption. The envelope is the
        // stable place for export metadata and provenance going forward.
        root["schemaVersion"] = Self.jsonSchemaVersion
        root["export"] = jsonExportMetadata(for: sanitized, options: options)

        return (try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
    }

    private func jsonExportMetadata(for document: ReaderDocument, options: ExportOptions) -> [String: Any] {
        guard options.includeProvenance else {
            return [
                "format": ExportFormat.json.rawValue,
                "schemaVersion": Self.jsonSchemaVersion,
                "provenanceIncluded": false,
                "reviewSummaryIncluded": false
            ]
        }
        let findings = DocumentEditing.reviewFindings(for: document)
        var provenance: [String: Any] = [
            "documentID": document.id.uuidString.lowercased(),
            "sourceType": document.sourceType.rawValue,
            "processingStatus": document.processingStatus.rawValue,
            "pageCount": document.pages.count,
            "blockCount": document.allBlocks.count,
            "reviewedBlockCount": document.allBlocks.filter(DocumentEditing.isReviewed).count,
            "unresolvedFindingCount": findings.filter { !$0.isResolved }.count,
            "sourceURLRedacted": options.redactSourceURL
        ]
        if !options.redactSourceURL, let sourceURL = document.sourceURL?.absoluteString {
            provenance["sourceURL"] = sourceURL
        }

        // The review summary is deliberately nested inside the additive
        // provenance envelope. It gives downstream consumers the same
        // grounded summary/citation contract used by the review UI without
        // changing any legacy ReaderDocument fields. Anonymous exports keep
        // the review signal and stable locations, but never copy extracted
        // prose into this new envelope.
        provenance["reviewSummary"] = jsonReviewSummary(for: document, options: options)
        provenance["reviewFindings"] = jsonReviewFindings(for: document, options: options)

        return [
            "format": ExportFormat.json.rawValue,
            "schemaVersion": Self.jsonSchemaVersion,
            "provenanceIncluded": true,
            "reviewSummaryIncluded": true,
            "provenance": provenance
        ]
    }

    private func jsonReviewSummary(for document: ReaderDocument, options: ExportOptions) -> [String: Any] {
        let length: SummaryLength = .medium
        let grounded = ExplanationEngine().groundedSummary(for: document, length: length)
        let includesText = !options.redactTextSnippets

        let citations: [[String: Any]] = grounded.citations.map { citation in
            var value: [String: Any] = [
                "id": citation.id,
                "pageNumber": citation.pageNumber,
                "blockID": citation.blockID.uuidString.lowercased(),
                "excerptIncluded": includesText
            ]
            if includesText {
                value["excerpt"] = citation.excerpt
            }
            return value
        }

        var result: [String: Any] = [
            "summaryLength": length.rawValue,
            "summaryTextIncluded": includesText,
            "citationExcerptsIncluded": includesText,
            "citationCount": grounded.citations.count,
            "citations": citations
        ]
        if includesText {
            result["summaryText"] = grounded.text
        }
        if let warning = grounded.groundingWarning {
            result["groundingWarning"] = warning
        }
        return result
    }

    private func jsonReviewFindings(for document: ReaderDocument, options: ExportOptions) -> [[String: Any]] {
        let dateFormatter = ISO8601DateFormatter()
        return DocumentEditing.reviewFindings(for: document).map { finding in
            var result: [String: Any] = [
                "id": finding.id,
                "kind": finding.kind.rawValue,
                "severity": finding.severity.rawValue,
                "pageNumber": finding.pageNumber,
                "isResolved": finding.isResolved
            ]
            if !options.redactTextSnippets {
                result["title"] = finding.title
                result["detail"] = finding.detail
            }
            if let blockID = finding.blockID {
                result["blockID"] = blockID.uuidString.lowercased()
            }
            if let provenance = finding.provenance {
                var provenanceJSON: [String: Any] = [
                    "source": provenance.source.rawValue,
                    "pageNumber": provenance.pageNumber,
                    "createdAt": dateFormatter.string(from: provenance.createdAt)
                ]
                if let parentBlockID = provenance.parentBlockID {
                    provenanceJSON["parentBlockID"] = parentBlockID.uuidString.lowercased()
                }
                if let bounds = provenance.bounds {
                    provenanceJSON["bounds"] = ["x": bounds.x, "y": bounds.y, "width": bounds.width, "height": bounds.height]
                }
                result["provenance"] = provenanceJSON
            }
            return result
        }
    }

    private func sanitizedDocument(_ document: ReaderDocument, options: ExportOptions) -> ReaderDocument {
        var copy = document
        if options.redactSourceURL {
            copy.sourceURL = nil
        }
        return copy
    }

    private func markdownTable(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "" }
        let separator = Array(repeating: "---", count: header.count)
        let dataRows = rows.dropFirst()
        return ([header, separator] + dataRows)
            .map { "| " + $0.map(markdownTableCell).joined(separator: " | ") + " |" }
            .joined(separator: "\n")
    }

    private func markdownTableCell(_ text: String) -> String {
        markdownInline(text).replacingOccurrences(of: "|", with: "\\|")
    }

    private func markdownInline(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func htmlTable(
        _ rows: [[String]],
        pageNumber: Int? = nil,
        blockID: String? = nil,
        columnHeaderRows: [Int] = [],
        rowHeaderColumns: [Int] = []
    ) -> String {
        guard let header = rows.first else { return "<table></table>" }
        let pageAttribute = pageNumber.map { " data-page=\"\($0)\"" } ?? ""
        let idAttribute = blockID.map { " id=\"\($0)\"" } ?? ""
        let columnHeaders = Set(columnHeaderRows)
        let rowHeaders = Set(rowHeaderColumns)
        if columnHeaders.isEmpty && rowHeaders.isEmpty {
            var legacy = ["<table\(idAttribute)\(pageAttribute)>", "<thead><tr>\(header.map { "<th scope=\"col\">\(escape($0))</th>" }.joined())</tr></thead>", "<tbody>"]
            for row in rows.dropFirst() {
                legacy.append("<tr>\(row.map { "<td>\(escape($0))</td>" }.joined())</tr>")
            }
            legacy.append("</tbody></table>")
            return legacy.joined(separator: "\n")
        }
        var html = ["<table\(idAttribute)\(pageAttribute)>", "<tbody>"]
        for (rowIndex, row) in rows.enumerated() {
            let cells = row.enumerated().map { columnIndex, value in
                if columnHeaders.contains(rowIndex) {
                    return "<th scope=\"col\">\(escape(value))</th>"
                }
                if rowHeaders.contains(columnIndex) {
                    return "<th scope=\"row\">\(escape(value))</th>"
                }
                return "<td>\(escape(value))</td>"
            }.joined()
            html.append("<tr>\(cells)</tr>")
        }
        html.append("</tbody></table>")
        return html.joined(separator: "\n")
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func csvEscape(_ text: String) -> String {
        let safeText = neutralizedSpreadsheetFormula(text)
        // Quote every RFC 4180 field containing a delimiter, quote, or either
        // line-ending character. This keeps embedded CRLF text in one cell
        // and makes output deterministic across source/platform line endings.
        if safeText.contains(",") || safeText.contains("\"") || safeText.contains("\n") || safeText.contains("\r") {
            return "\"\(safeText.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return safeText
    }

    private func neutralizedSpreadsheetFormula(_ text: String) -> String {
        let leadingCharacters = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        let visibleStart = text.unicodeScalars.firstIndex { !leadingCharacters.contains($0) }
        guard let visibleStart else {
            return text
        }

        if ["=", "+", "-", "@"].contains(text.unicodeScalars[visibleStart]) {
            return "'\(text)"
        }
        return text
    }

    private func pdfElements(for document: ReaderDocument, options: ExportOptions) -> [PDFTextElement] {
        var elements: [PDFTextElement] = [
            PDFTextElement(text: document.title, font: .boldSystemFont(ofSize: 20), spacingAfter: 18)
        ]

        for page in document.pages {
            if options.includePageReferences {
                elements.append(PDFTextElement(text: "Page \(page.pageNumber)", font: .boldSystemFont(ofSize: 15), spacingAfter: 10))
            }

            for block in DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters) {
                switch block.type {
                case .heading where options.includeHeadings:
                    elements.append(PDFTextElement(text: block.text, font: .boldSystemFont(ofSize: 15), spacingAfter: 8))
                case .table where options.includeTables:
                    if let table = page.tables.first(where: { $0.bounds == block.bounds }) {
                        let tableText = table.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
                        elements.append(PDFTextElement(text: tableText, font: .monospacedSystemFont(ofSize: 12, weight: .regular), spacingAfter: 6))
                        elements.append(PDFTextElement(text: "Table note: \(table.explanation)", font: .systemFont(ofSize: 12), spacingAfter: 10))
                    } else {
                        elements.append(PDFTextElement(text: block.text, font: .systemFont(ofSize: 13), spacingAfter: 8))
                    }
                case .figure where options.includeFigures:
                    let description = page.figures.first(where: { $0.bounds == block.bounds })?.description ?? block.text
                    elements.append(PDFTextElement(text: "Figure: \(description)", font: .systemFont(ofSize: 13), spacingAfter: 10))
                default:
                    elements.append(PDFTextElement(text: block.text, font: .systemFont(ofSize: 13), spacingAfter: 8))
                }

                if options.includeConfidenceNotes, block.confidence < 0.7 {
                    elements.append(PDFTextElement(text: "Confidence: \(Int(block.confidence * 100))%. Review recommended.", font: .systemFont(ofSize: 11), spacingAfter: 8))
                }
            }
        }

        return elements.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private struct PDFTextElement {
    let text: String
    let font: NSFont
    let spacingAfter: CGFloat

    private var attributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = 2
        return style
    }

    func height(constrainedTo width: CGFloat) -> CGFloat {
        let bounding = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return ceil(bounding.height)
    }

    func draw(in rect: NSRect) {
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
    }
}
