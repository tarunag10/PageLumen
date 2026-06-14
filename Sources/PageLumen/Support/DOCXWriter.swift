import Compression
import Foundation
import PageLumenCore

public struct DOCXWriter: Sendable {
    public init() {}

    public func data(for document: ReaderDocument, options: ExportOptions) -> Data {
        let archive = buildArchive(for: document, options: options)
        return zipStore(archive: archive)
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
        rows.append("      <w:tblGrid></w:tblGrid>")
        for (rowIndex, row) in table.rows.enumerated() {
            rows.append("      <w:tr>")
            for cell in row {
                if rowIndex == 0 {
                    rows.append("        \(paragraph(text: cell, style: "Strong"))")
                } else {
                    rows.append("        \(paragraph(text: cell))")
                }
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

    private func zipStore(archive: [String: Data]) -> Data {
        var centralDirectory = ZipCentralDirectory()
        var output = Data()
        for (path, fileData) in archive.sorted(by: { $0.key < $1.key }) {
            let entry = ZipStoreEntry(name: path, payload: fileData)
            let localHeader = entry.localHeader()
            output.append(localHeader)
            output.append(entry.compressedPayload())
            centralDirectory.add(entry: entry, offset: UInt32(output.count - fileData.count - localHeader.count))
        }
        let centralData = centralDirectory.data()
        output.append(centralData)
        var endOfCentralDirectory = ZipEndOfCentralDirectory()
        endOfCentralDirectory.totalEntries = UInt16(centralDirectory.entries.count)
        endOfCentralDirectory.centralDirectorySize = UInt32(centralData.count)
        endOfCentralDirectory.centralDirectoryOffset = UInt32(output.count - centralData.count)
        output.append(endOfCentralDirectory.data())
        return output
    }
}

private struct ZipStoreEntry {
    let name: String
    let payload: Data
    let crc32: UInt32
    let modificationDate: UInt16
    let modificationTime: UInt16

    init(name: String, payload: Data) {
        self.name = name
        self.payload = payload
        self.crc32 = ZipStoreEntry.crc32(payload)
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let year = max(0, (components.year ?? 1980) - 1980)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2
        self.modificationDate = UInt16((year << 9) | (month << 5) | day)
        self.modificationTime = UInt16((hour << 11) | (minute << 5) | second)
    }

    func localHeader() -> Data {
        var data = Data()
        data.appendLE(UInt32(0x04034b50))
        data.appendLE(UInt16(20))
        data.appendLE(UInt16(0))
        data.appendLE(UInt16(0))
        data.appendLE(modificationTime)
        data.appendLE(modificationDate)
        data.appendLE(crc32)
        data.appendLE(UInt32(payload.count))
        data.appendLE(UInt32(payload.count))
        data.appendLE(UInt16(name.utf8.count))
        data.appendLE(UInt16(0))
        let nameData = Data(name.utf8)
        data.append(nameData)
        return data
    }

    func compressedPayload() -> Data {
        payload
    }

    func centralDirectoryEntry(fileHeaderOffset: UInt32) -> Data {
        var data = Data()
        data.appendLE(UInt32(0x02014b50))
        data.appendLE(UInt16(20))
        data.appendLE(UInt16(20))
        data.appendLE(UInt16(0))
        data.appendLE(UInt16(0))
        data.appendLE(modificationTime)
        data.appendLE(modificationDate)
        data.appendLE(crc32)
        data.appendLE(UInt32(payload.count))
        data.appendLE(UInt32(payload.count))
        data.appendLE(UInt16(name.utf8.count))
        data.appendLE(UInt16(0))
        data.appendLE(UInt16(0))
        data.appendLE(UInt16(0))
        data.appendLE(UInt16(0))
        data.appendLE(UInt32(0))
        data.appendLE(fileHeaderOffset)
        let nameData = Data(name.utf8)
        data.append(nameData)
        return data
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ Self.crcTable[index]
        }
        return crc ^ 0xffffffff
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()
}

private struct ZipCentralDirectory {
    var entries: [(entry: ZipStoreEntry, offset: UInt32)] = []

    mutating func add(entry: ZipStoreEntry, offset: UInt32) {
        entries.append((entry, offset))
    }

    func data() -> Data {
        var data = Data()
        for (entry, offset) in entries {
            data.append(entry.centralDirectoryEntry(fileHeaderOffset: offset))
        }
        return data
    }
}

private struct ZipEndOfCentralDirectory {
    var totalEntries: UInt16 = 0
    var centralDirectorySize: UInt32 = 0
    var centralDirectoryOffset: UInt32 = 0

    func data() -> Data {
        var data = Data()
        data.appendLE(UInt32(0x06054b50))
        data.appendLE(UInt16(0))
        data.appendLE(UInt16(0))
        data.appendLE(totalEntries)
        data.appendLE(totalEntries)
        data.appendLE(centralDirectorySize)
        data.appendLE(centralDirectoryOffset)
        data.appendLE(UInt16(0))
        return data
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
