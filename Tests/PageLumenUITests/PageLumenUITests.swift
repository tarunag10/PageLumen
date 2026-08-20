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

    func testFixtureLaunchExposesReviewAndExportWorkflow() throws {
        let fixtureApp = XCUIApplication()
        fixtureApp.launchArguments = ["-ui-testing", "-ui-testing-fixture"]
        fixtureApp.launch()

        XCTAssertTrue(fixtureApp.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(fixtureApp.buttons["review.queue"].waitForExistence(timeout: 3))
        XCTAssertTrue(fixtureApp.buttons["review.continue"].exists)

        fixtureApp.buttons["review.continue"].click()
        XCTAssertTrue(fixtureApp.buttons["export.backToReview"].waitForExistence(timeout: 3))
        XCTAssertTrue(fixtureApp.buttons["export.Markdown"].exists)
        XCTAssertTrue(fixtureApp.buttons["export.Tagged HTML"].exists)
    }

    func testSettingsLaunchExposesPrivacyAndAppearanceControls() throws {
        let settingsApp = XCUIApplication()
        settingsApp.launchArguments = ["-ui-testing", "-ui-testing-settings"]
        settingsApp.launch()

        XCTAssertTrue(settingsApp.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsApp.checkBoxes["settings.privacyMode"].waitForExistence(timeout: 3))
        XCTAssertTrue(settingsApp.checkBoxes["settings.searchableCopies"].exists)
        XCTAssertTrue(settingsApp.popUpButtons["settings.appearance"].exists)
        XCTAssertTrue(settingsApp.checkBoxes["settings.boostContrast"].exists)
        XCTAssertTrue(settingsApp.buttons["settings.forgetAll"].exists)
    }
}
