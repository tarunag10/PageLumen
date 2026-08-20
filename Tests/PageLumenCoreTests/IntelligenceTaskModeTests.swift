import XCTest
@testable import PageLumenCore

final class IntelligenceTaskModeTests: XCTestCase {
    func testModesAreClosedAndUserFacing() {
        XCTAssertEqual(IntelligenceTaskMode.allCases.count, 5)
        XCTAssertEqual(IntelligenceTaskMode.studyNotes.title, "Create study notes")
        XCTAssertEqual(IntelligenceTaskMode.comparePassages.title, "Compare passages")
    }

    func testStudyNotesAndComparisonPromptsStayBoundedAndCited() {
        let blockID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let context = BoundedIntelligenceContext(
            prompt: "[Source page 2, block \(blockID.uuidString)] A bounded passage.",
            metadata: IntelligenceContextMetadata(
                isSelectionScoped: true, requestedBlockCount: 1, sourceBlockCount: 2,
                includedBlockCount: 1, omittedBlockCount: 1, includedPageNumbers: [2],
                omittedPageNumbers: [3], includedSectionLabels: [], omittedSectionLabels: []
            )
        )
        let notes = IntelligenceTaskPrompt.prompt(mode: .studyNotes, context: context)
        let comparison = IntelligenceTaskPrompt.prompt(mode: .comparePassages, context: context)
        XCTAssertTrue(notes.contains("review questions"))
        XCTAssertTrue(comparison.contains("agreements, differences"))
        XCTAssertTrue(notes.contains(blockID.uuidString))
        XCTAssertTrue(comparison.contains("omitted"))
    }
}
