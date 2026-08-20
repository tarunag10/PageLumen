import XCTest

/// Deterministic UI contract checks for the primary launch surface.
///
/// These tests intentionally assert only stable, user-visible controls. OCR,
/// Screen Recording permission, and export dialogs require a participant or a
/// controlled fixture run and remain separate manual gates.
final class PageLumenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testHomeExposesPrimaryImportActions() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "PageLumen main window did not launch")

        XCTAssertTrue(app.buttons["home.openFiles"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.pasteImage"].exists)
        XCTAssertTrue(app.buttons["home.captureScreen"].exists)
        XCTAssertTrue(app.buttons["home.tryDemo"].exists)
    }

    func testHomeExposesWorkflowNavigation() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        let steps = ["Add", "Process", "Review", "Export"]
        for (index, step) in steps.enumerated() {
            XCTAssertTrue(
                app.buttons["Step \(index + 1), \(step)"].exists,
                "Missing accessible workflow step: \(step)"
            )
        }
    }
}
