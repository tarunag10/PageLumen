import XCTest
@testable import PageLumenCore

final class AISummaryProvenanceTests: XCTestCase {
    func testAcceptedBlockLineageRoundTripsWithoutSourceText() throws {
        let parentID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let lineage = AIBlockLineage(
            contentKind: .description,
            sessionID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            requestID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            provider: "apple-foundation-models",
            modelIdentifier: "SystemLanguageModel.default",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            parentSources: [GroundedSourceReference(pageNumber: 4, blockID: parentID)]
        )
        let provenance = BlockProvenance(
            source: .appleIntelligence,
            pageNumber: 4,
            parentBlockID: parentID,
            engine: "apple-foundation-models",
            aiLineage: lineage
        )

        let data = try JSONEncoder().encode(provenance)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("secret source passage"))
        XCTAssertFalse(json.contains("prompt"))
        XCTAssertFalse(json.contains("response"))
        XCTAssertEqual(try JSONDecoder().decode(BlockProvenance.self, from: data), provenance)
        XCTAssertEqual(lineage.parentSources, [GroundedSourceReference(pageNumber: 4, blockID: parentID)])
    }

    func testProvenanceRoundTripsWithoutPromptOrResponseDiagnostics() throws {
        let blockID = UUID()
        let context = IntelligenceContextMetadata(
            isSelectionScoped: true,
            requestedBlockCount: 2,
            sourceBlockCount: 8,
            includedBlockCount: 2,
            omittedBlockCount: 6,
            includedPageNumbers: [2],
            omittedPageNumbers: [3, 4],
            includedSectionLabels: ["Results"],
            omittedSectionLabels: ["Appendix"]
        )
        let provenance = AISummaryProvenance(
            sessionID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            requestID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            provider: "apple-foundation-models",
            modelIdentifier: "SystemLanguageModel.default",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            summaryLength: .medium,
            context: context,
            citedPageBlockIDs: [GroundedSourceReference(pageNumber: 2, blockID: blockID)]
        )

        let data = try JSONEncoder().encode(provenance)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("prompt"))
        XCTAssertFalse(json.contains("response"))
        XCTAssertEqual(try JSONDecoder().decode(AISummaryProvenance.self, from: data), provenance)
    }

    func testReaderDocumentPersistsOptionalSummaryProvenance() throws {
        let provenance = AISummaryProvenance(
            provider: "apple-foundation-models",
            modelIdentifier: "SystemLanguageModel.default",
            summaryLength: .short,
            context: IntelligenceContextMetadata(
                isSelectionScoped: false,
                requestedBlockCount: 1,
                sourceBlockCount: 1,
                includedBlockCount: 1,
                omittedBlockCount: 0,
                includedPageNumbers: [1],
                omittedPageNumbers: [],
                includedSectionLabels: [],
                omittedSectionLabels: []
            ),
            citedPageBlockIDs: []
        )
        let document = ReaderDocument(
            title: "Provenance",
            sourceType: .sample,
            pages: [],
            summary: "Generated draft",
            summaryProvenance: provenance
        )

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(ReaderDocument.self, from: data)
        XCTAssertEqual(decoded.summaryProvenance, provenance)
        XCTAssertEqual(decoded.summary, "Generated draft")
    }

    func testAnonymousJSONExportKeepsScopeCountsButRedactsSectionLabels() throws {
        let provenance = AISummaryProvenance(
            provider: "apple-foundation-models",
            modelIdentifier: "SystemLanguageModel.default",
            summaryLength: .detailed,
            context: IntelligenceContextMetadata(
                isSelectionScoped: false,
                requestedBlockCount: 3,
                sourceBlockCount: 5,
                includedBlockCount: 3,
                omittedBlockCount: 2,
                includedPageNumbers: [1, 2],
                omittedPageNumbers: [3],
                includedSectionLabels: ["Private diagnosis"],
                omittedSectionLabels: ["Private appendix"]
            ),
            citedPageBlockIDs: []
        )
        let document = ReaderDocument(
            title: "Anonymous",
            sourceType: .sample,
            pages: [],
            summaryProvenance: provenance
        )

        let data = ExportEngine().jsonData(for: document, options: .anonymous)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let export = try XCTUnwrap(root["export"] as? [String: Any])
        let envelope = try XCTUnwrap(export["provenance"] as? [String: Any])
        let summary = try XCTUnwrap(envelope["reviewSummary"] as? [String: Any])
        let generation = try XCTUnwrap(summary["generationProvenance"] as? [String: Any])
        let context = try XCTUnwrap(generation["context"] as? [String: Any])

        XCTAssertEqual(context["includedBlockCount"] as? Int, 3)
        XCTAssertEqual(context["omittedPageNumbers"] as? [Int], [3])
        XCTAssertNil(context["includedSectionLabels"])
        XCTAssertNil(context["omittedSectionLabels"])
        XCTAssertNil(root["summaryProvenance"])
    }
}
