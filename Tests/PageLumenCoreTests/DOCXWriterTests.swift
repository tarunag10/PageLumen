import Foundation
import PageLumenCore
import XCTest
@testable import PageLumen

final class DOCXWriterTests: XCTestCase {
    func testDOCXOutputIsAValidZipArchive() {
        let document = SampleDataFactory.makeDemoDocument()
        let data = DOCXWriter().data(for: document, options: .full)

        XCTAssertGreaterThan(data.count, 100)
        let prefix = [UInt8](data.prefix(4))
        XCTAssertEqual(prefix, [0x50, 0x4B, 0x03, 0x04])
    }

    func testDOCXOutputContainsDocumentXMLWithTitle() {
        let document = SampleDataFactory.makeDemoDocument()
        let data = DOCXWriter().data(for: document, options: .full)

        let entries = parseZipEntries(in: data)
        let documentXMLEntry = entries.first { $0.name == "word/document.xml" }
        XCTAssertNotNil(documentXMLEntry, "DOCX archive must contain word/document.xml")

        let xmlString = String(data: documentXMLEntry!.payload, encoding: .utf8) ?? ""
        XCTAssertTrue(xmlString.contains(document.title), "Document XML should contain the document title")
        XCTAssertTrue(xmlString.contains("IMPORT FLOW"), "Document XML should include the first heading")
    }

    func testDOCXArchiveContainsExpectedPackageParts() {
        let document = SampleDataFactory.makeDemoDocument()
        let data = DOCXWriter().data(for: document, options: .full)
        let names = Set(parseZipEntries(in: data).map(\.name))

        XCTAssertTrue(names.contains("[Content_Types].xml"))
        XCTAssertTrue(names.contains("_rels/.rels"))
        XCTAssertTrue(names.contains("word/_rels/document.xml.rels"))
        XCTAssertTrue(names.contains("word/document.xml"))
    }

    func testExportFormatDOCXExposesDocxExtension() {
        XCTAssertEqual(ExportFormat.docx.fileExtension, "docx")
        XCTAssertEqual(ExportFormat.docx.rawValue, "DOCX")
    }

    private struct ZipEntry {
        let name: String
        let payload: Data
    }

    private func parseZipEntries(in data: Data) -> [ZipEntry] {
        var entries: [ZipEntry] = []
        var cursor = 0
        let bytes = [UInt8](data)
        while cursor + 4 <= bytes.count {
            let signature = readUInt32(bytes, at: cursor)
            if signature == 0x04034b50 {
                guard cursor + 30 <= bytes.count else { break }
                let compressionMethod = readUInt16(bytes, at: cursor + 8)
                let compressedSize = Int(readUInt32(bytes, at: cursor + 18))
                let uncompressedSize = Int(readUInt32(bytes, at: cursor + 22))
                let nameLength = Int(readUInt16(bytes, at: cursor + 26))
                let extraLength = Int(readUInt16(bytes, at: cursor + 28))
                let nameStart = cursor + 30
                let nameEnd = nameStart + nameLength
                guard nameEnd + extraLength <= bytes.count else { break }
                let name = String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8) ?? ""
                let payloadStart = nameEnd + extraLength
                let payloadSize = compressionMethod == 0 ? compressedSize : uncompressedSize
                let payloadEnd = payloadStart + payloadSize
                guard payloadEnd <= bytes.count else { break }
                let payload = Data(bytes[payloadStart..<payloadEnd])
                entries.append(ZipEntry(name: name, payload: payload))
                cursor = payloadEnd
            } else if signature == 0x02014b50 || signature == 0x06054b50 {
                break
            } else {
                break
            }
        }
        return entries
    }

    private func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}
