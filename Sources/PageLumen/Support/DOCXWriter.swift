import Foundation
import PageLumenCore
import ZIPFoundation

/// Writes the parts of an Office Open XML package to a DOCX archive.
///
/// Keeping this seam separate from OOXML generation makes the package writer
/// replaceable and keeps archive framing, path validation, and temporary-file
/// cleanup in one audited implementation.
public protocol DOCXArchiveWriting: Sendable {
    func write(parts: [String: Data]) -> Data
}

/// The shipping DOCX archive implementation. ZIPFoundation owns ZIP framing,
/// CRC calculation, and archive path handling; PageLumen does not maintain a
/// second ZIP implementation.
public struct ZIPFoundationDOCXArchiveWriter: DOCXArchiveWriting, Sendable {
    public init() {}

    public func write(parts: [String: Data]) -> Data {
        guard !parts.isEmpty,
              parts.keys.allSatisfy(Self.isSafePartPath),
              parts.values.allSatisfy({ $0.count <= Int(UInt32.max) }) else {
            return Data()
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pagelumen-docx-\(UUID().uuidString)", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let destination = try Archive(url: url, accessMode: .create)
            for (path, payload) in parts.sorted(by: { $0.key < $1.key }) {
                try destination.addEntry(
                    with: path,
                    type: .file,
                    uncompressedSize: Int64(payload.count),
                    // Store OOXML parts without compression so lightweight
                    // package inspectors can validate them without a
                    // decompressor. ZIPFoundation still owns archive framing.
                    compressionMethod: .none
                ) { position, size in
                    guard position >= 0, position <= Int64(payload.count), position <= Int64(Int.max) else {
                        return Data()
                    }
                    let start = Int(position)
                    let end = min(start + size, payload.count)
                    return start < end ? payload.subdata(in: start..<end) : Data()
                }
            }
            return try Data(contentsOf: url)
        } catch {
            // DOCXWriter's public API is intentionally non-throwing to retain
            // compatibility with the existing save-panel flow.
            return Data()
        }
    }

    private static func isSafePartPath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { $0 != ".." && $0 != "." && !$0.isEmpty }
    }
}

public struct DOCXWriter: Sendable {
    private let archiveWriter: any DOCXArchiveWriting

    public init() {
        self.init(archiveWriter: ZIPFoundationDOCXArchiveWriter())
    }

    public init(archiveWriter: any DOCXArchiveWriting = ZIPFoundationDOCXArchiveWriter()) {
        self.archiveWriter = archiveWriter
    }

    public func data(for document: ReaderDocument, options: ExportOptions) -> Data {
        let archive = buildArchive(for: document, options: options)
        return archiveWriter.write(parts: archive)
    }

    private func buildArchive(for document: ReaderDocument, options: ExportOptions) -> [String: Data] {
        var archive: [String: Data] = [:]
        archive["[Content_Types].xml"] = contentTypesXML().data(using: .utf8) ?? Data()
        archive["_rels/.rels"] = rootRelsXML().data(using: .utf8) ?? Data()
        archive["word/_rels/document.xml.rels"] = documentRelsXML().data(using: .utf8) ?? Data()
        archive["word/document.xml"] = documentXML(for: document, options: options).data(using: .utf8) ?? Data()
        return archive
    }

    private func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
    }

    private func rootRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private func documentRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """
    }

    private func documentXML(for document: ReaderDocument, options: ExportOptions) -> String {
        var body = [String]()
        body.append("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:rPr><w:sz w:val="40"/></w:rPr><w:t xml:space="preserve">\(xmlEscape(document.title))</w:t></w:r></w:p>
        """)

        for page in document.pages {
            if options.includePageReferences {
                body.append("    <w:p><w:pPr><w:pStyle w:val=\"Heading2\"/></w:pPr><w:r><w:t xml:space=\"preserve\">Page \(page.pageNumber)</w:t></w:r></w:p>")
            }
            for block in DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: options.includeHeadersAndFooters) {
                switch block.type {
                case .heading where options.includeHeadings:
                    body.append("    \(paragraph(text: block.text, style: "Heading1"))")
                case .table where options.includeTables:
                    if let table = page.tables.first(where: { $0.bounds == block.bounds }) {
                        body.append(contentsOf: tableRows(table))
                        if !table.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            body.append("    \(paragraph(text: "Table note: \(table.explanation)", style: "Caption"))")
                        }
                    } else {
                        body.append("    \(paragraph(text: block.text))")
                    }
                case .figure where options.includeFigures:
                    let description = page.figures.first(where: { $0.bounds == block.bounds })?.description ?? block.text
                    body.append("    \(paragraph(text: "Figure: \(description)", style: "Caption"))")
                default:
                    body.append("    \(paragraph(text: block.text))")
                }
            }
        }

        body.append("  </w:body>")
        body.append("</w:document>")
        return body.joined(separator: "\n")
    }

    private func paragraph(text: String, style: String? = nil) -> String {
        let styleXML = style.map { "<w:pPr><w:pStyle w:val=\"\($0)\"/></w:pPr>" } ?? ""
        return "<w:p>\(styleXML)<w:r><w:t xml:space=\"preserve\">\(xmlEscape(text))</w:t></w:r></w:p>"
    }

    private func tableRows(_ table: TableRegion) -> [String] {
        var rows: [String] = []
        rows.append("    <w:tbl>")
        rows.append("      <w:tblPr><w:tblW w:w=\"0\" w:type=\"auto\"/></w:tblPr>")
        let columnCount = table.rows.map(\.count).max() ?? 0
        let gridColumns = (0..<columnCount)
            .map { _ in "<w:gridCol w:w=\"2400\"/>" }
            .joined()
        rows.append("      <w:tblGrid>\(gridColumns)</w:tblGrid>")
        for (rowIndex, row) in table.rows.enumerated() {
            rows.append("      <w:tr>")
            for cell in row {
                let style = rowIndex == 0 ? "Strong" : nil
                rows.append("        <w:tc>\(paragraph(text: cell, style: style))</w:tc>")
            }
            rows.append("      </w:tr>")
        }
        rows.append("    </w:tbl>")
        return rows
    }

    private func xmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

}
