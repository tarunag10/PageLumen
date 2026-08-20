import Foundation
import PageLumenCore
import XCTest
@testable import PageLumen

final class DOCXWriterTests: XCTestCase {
    func testDOCXWriterDelegatesPackageAssemblyToArchiveWriter() {
        let archiveWriter = RecordingDOCXArchiveWriter()
        let result = DOCXWriter(archiveWriter: archiveWriter).data(
            for: SampleDataFactory.makeDemoDocument(),
            options: .full
        )

        XCTAssertEqual(result, Data([0x44, 0x4F, 0x43, 0x58]))
        XCTAssertEqual(Set(archiveWriter.parts.keys), [
            "[Content_Types].xml",
            "_rels/.rels",
            "word/_rels/document.xml.rels",
            "word/document.xml"
        ])
        XCTAssertTrue(String(data: archiveWriter.parts["word/document.xml"] ?? Data(), encoding: .utf8)?.contains("IMPORT FLOW") == true)
    }

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

    func testDOCXPackageValidatorAcceptsGeneratedPackage() {
        let data = DOCXWriter().data(for: SampleDataFactory.makeDemoDocument(), options: .full)

        let validation = DOCXPackageValidator.validate(parts: packageParts(from: data))

        XCTAssertTrue(validation.isValid, "Generated DOCX should pass deterministic OOXML checks: \(validation.issues)")
    }

    func testDOCXPackageValidatorReportsMissingRequiredPart() {
        let validation = DOCXPackageValidator.validate(parts: [
            "word/document.xml": Data("<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body/></w:document>".utf8)
        ])

        XCTAssertEqual(validation.issues, [.missingRequiredPart])
    }

    func testDOCXPackageValidatorReportsMalformedOOXML() {
        let validation = DOCXPackageValidator.validate(parts: [
            "[Content_Types].xml": Data("<Types>".utf8),
            "_rels/.rels": Data("<Relationships/>".utf8),
            "word/_rels/document.xml.rels": Data("<Relationships/>".utf8),
            "word/document.xml": Data("<w:document>".utf8)
        ])

        XCTAssertEqual(validation.issues, [.invalidXML])
    }

    func testDOCXOutputPassesIndependentSystemUnzipConsumer() throws {
        let data = DOCXWriter().data(for: SampleDataFactory.makeDemoDocument(), options: .full)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pagelumen-docx-consumer-\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url, options: .atomic)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-tqq", url.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0,
                       "Independent unzip consumer rejected the generated DOCX")
    }

    func testDOCXPackageValidatorRejectsUnsafeAndDanglingRelationships() {
        let valid = """
        <?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="officeDocument" Target="word/document.xml"/>
          <Relationship Id="rId2" Type="image" Target="missing/image.png"/>
        </Relationships>
        """
        let external = valid.replacingOccurrences(of: "Target=\"missing/image.png\"", with: "Target=\"https://example.invalid/a.png\" TargetMode=\"External\"")
        let parts: [String: Data] = [
            "[Content_Types].xml": Data("<Types><Default Extension=\"rels\"/><Default Extension=\"xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>".utf8),
            "_rels/.rels": Data(valid.utf8),
            "word/_rels/document.xml.rels": Data(external.utf8),
            "word/document.xml": Data("<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body></w:body></w:document>".utf8),
            "../outside.xml": Data()
        ]

        let validation = DOCXPackageValidator.validate(parts: parts)

        XCTAssertTrue(validation.issues.contains(.unsafePartPath))
        XCTAssertTrue(validation.issues.contains(.externalRelationship))
    }

    func testDOCXTablesUseWordprocessingMLTableCells() {
        let document = SampleDataFactory.makeDemoDocument()
        let data = DOCXWriter().data(for: document, options: .full)
        let entries = parseZipEntries(in: data)
        let documentXML = entries.first { $0.name == "word/document.xml" }
        let xml = String(data: documentXML?.payload ?? Data(), encoding: .utf8) ?? ""

        // The demo table has three rows and two columns. WordprocessingML
        // requires every cell to be wrapped in w:tc under its w:tr parent.
        XCTAssertEqual(xml.components(separatedBy: "<w:tc>").count - 1, 6)
        XCTAssertEqual(xml.components(separatedBy: "</w:tc>").count - 1, 6)
        XCTAssertTrue(xml.contains("<w:tc><w:p>"))
        XCTAssertFalse(xml.contains("<w:tr>\n        <w:p"))
        XCTAssertTrue(xml.contains("<w:gridCol w:w=\"2400\"/>"))
    }

    func testDOCXRoundTripPreservesOOXMLTextEscaping() {
        var document = SampleDataFactory.makeDemoDocument()
        document.title = "A & B <review>"
        let data = DOCXWriter().data(for: document, options: .full)
        let entries = parseZipEntries(in: data)
        let xml = String(data: entries.first { $0.name == "word/document.xml" }?.payload ?? Data(), encoding: .utf8) ?? ""

        XCTAssertTrue(xml.contains("A &amp; B &lt;review&gt;"))
        XCTAssertFalse(xml.contains("A & B <review>"))
        XCTAssertTrue(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"))
    }

    func testExportFormatDOCXExposesDocxExtension() {
        XCTAssertEqual(ExportFormat.docx.fileExtension, "docx")
        XCTAssertEqual(ExportFormat.docx.rawValue, "DOCX")
    }

    private struct ZipEntry {
        let name: String
        let payload: Data
    }

    private final class RecordingDOCXArchiveWriter: DOCXArchiveWriting, @unchecked Sendable {
        var parts: [String: Data] = [:]

        func write(parts: [String: Data]) -> Data {
            self.parts = parts
            return Data([0x44, 0x4F, 0x43, 0x58])
        }
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

    private func packageParts(from data: Data) -> [String: Data] {
        Dictionary(uniqueKeysWithValues: parseZipEntries(in: data).map { ($0.name, $0.payload) })
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
