import AppKit
import Foundation

public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown = "Markdown"
    case text = "TXT"
    case html = "HTML"
    case pdf = "Accessible PDF"
    case csv = "CSV"
    case json = "JSON"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .text: return "txt"
        case .html: return "html"
        case .pdf: return "pdf"
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

public struct ExportEngine: Sendable {
    public init() {}

    public func markdown(for document: ReaderDocument, options: ExportOptions) -> String {
        var lines = ["# \(document.title)", ""]
        for page in document.pages {
            if options.includePageReferences {
                lines.append("## Page \(page.pageNumber)")
                lines.append("")
            }

            for block in DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters) {
                switch block.type {
                case .heading where options.includeHeadings:
                    lines.append("### \(block.text)")
                case .table where options.includeTables:
                    if let table = page.tables.first(where: { $0.bounds == block.bounds }) {
                        lines.append(markdownTable(table.rows))
                        lines.append("")
                        lines.append("> \(table.explanation)")
                    } else {
                        lines.append(block.text)
                    }
                case .figure where options.includeFigures:
                    if let figure = page.figures.first(where: { $0.bounds == block.bounds }) {
                        lines.append("Figure: \(figure.description)")
                    } else {
                        lines.append("Figure: \(block.text)")
                    }
                default:
                    lines.append(block.text)
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
                        body.append(htmlTable(table.rows))
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

    public func pdfData(for document: ReaderDocument, options: ExportOptions) -> Data {
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        let textRect = pageRect.insetBy(dx: 48, dy: 48)
        let view = NSTextView(frame: pageRect)
        view.textContainerInset = NSSize(width: textRect.minX, height: textRect.minY)
        view.string = plainText(for: document, options: options)
        view.font = NSFont.systemFont(ofSize: 13)
        view.textColor = .textColor
        view.backgroundColor = .textBackgroundColor
        return view.dataWithPDF(inside: pageRect)
    }

    public func data(for document: ReaderDocument, format: ExportFormat, options: ExportOptions) -> Data {
        switch format {
        case .markdown:
            return Data(markdown(for: document, options: options).utf8)
        case .text:
            return Data(plainText(for: document, options: options).utf8)
        case .html:
            return Data(html(for: document, options: options).utf8)
        case .pdf:
            return pdfData(for: document, options: options)
        case .csv:
            return Data(csv(for: document, options: options).utf8)
        case .json:
            return jsonData(for: document, options: options)
        }
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

        var filtered = document
        filtered.pages = document.pages.map { page in
            var copy = page
            copy.blocks = DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters)
            return copy
        }

        return (try? encoder.encode(filtered)) ?? Data("{}".utf8)
    }

    private func markdownTable(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "" }
        let separator = Array(repeating: "---", count: header.count)
        let dataRows = rows.dropFirst()
        return ([header, separator] + dataRows)
            .map { "| " + $0.joined(separator: " | ") + " |" }
            .joined(separator: "\n")
    }

    private func htmlTable(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "<table></table>" }
        var html = ["<table>", "<thead><tr>\(header.map { "<th>\(escape($0))</th>" }.joined())</tr></thead>", "<tbody>"]
        for row in rows.dropFirst() {
            html.append("<tr>\(row.map { "<td>\(escape($0))</td>" }.joined())</tr>")
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
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}
