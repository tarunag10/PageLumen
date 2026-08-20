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

    func testFixtureReviewToExportExposesAllControlsWithoutOpeningFilePanel() throws {
        let fixtureApp = XCUIApplication()
        fixtureApp.launchArguments = ["-ui-testing", "-ui-testing-fixture"]
        fixtureApp.launch()

        XCTAssertTrue(fixtureApp.buttons["review.queue"].waitForExistence(timeout: 5))
        fixtureApp.buttons["review.continue"].click()
        XCTAssertTrue(fixtureApp.buttons["export.backToReview"].waitForExistence(timeout: 3))

        // This is deliberately a control-surface contract. Clicking an export
        // format would invoke the native save panel, so confirmation and file
        // writing stay in the participant/release gate.
        let formats = [
            "Markdown", "TXT", "HTML", "Tagged HTML", "Readable PDF", "CSV",
            "JSON", "Accessibility Report", "Audio", "DOCX", "Translate and Export Markdown"
        ]
        for format in formats {
            XCTAssertTrue(
                fixtureApp.buttons["export.\(format)"].exists,
                "Missing export control: \(format)"
            )
        }

        let options = [
            "Include headings", "Include tables", "Include chart and figure explanations",
            "Include page references", "Include confidence notes",
            "Include repeated headers and footers", "Include provenance and review details"
        ]
        for option in options {
            XCTAssertTrue(
                fixtureApp.checkBoxes[option].exists,
                "Missing export option: \(option)"
            )
        }

        XCTAssertTrue(fixtureApp.staticTexts["Export preview"].exists)
        XCTAssertFalse(fixtureApp.sheets.firstMatch.exists, "Control-surface coverage must not open a save panel")
    }

    func testFixtureStirlingModeExposesConfirmedOperationControls() throws {
        let fixtureApp = XCUIApplication()
        fixtureApp.launchArguments = ["-ui-testing", "-ui-testing-fixture", "-ui-testing-stirling"]
        fixtureApp.launch()

        XCTAssertTrue(fixtureApp.buttons["review.queue"].waitForExistence(timeout: 5))
        fixtureApp.buttons["review.continue"].click()
        XCTAssertTrue(fixtureApp.buttons["export.backToReview"].waitForExistence(timeout: 3))
        XCTAssertTrue(fixtureApp.buttons["export.stirlingCompress"].exists)
        XCTAssertTrue(fixtureApp.buttons["export.stirlingMerge"].exists)
        XCTAssertFalse(fixtureApp.buttons["export.stirlingCancel"].exists)
        XCTAssertFalse(fixtureApp.sheets.firstMatch.exists)
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
        XCTAssertTrue(settingsApp.popUpButtons["settings.intelligenceMode"].exists)
        XCTAssertTrue(settingsApp.checkBoxes["settings.documentIntelligenceOptOut"].exists)
        XCTAssertTrue(settingsApp.staticTexts["settings.intelligenceAvailability"].exists)
        XCTAssertTrue(settingsApp.checkBoxes["settings.stirlingEnabled"].exists)
        XCTAssertTrue(settingsApp.textFields["settings.stirlingEndpoint"].exists)
        XCTAssertTrue(settingsApp.staticTexts["settings.stirlingEndpointState"].exists)
        XCTAssertTrue(settingsApp.buttons["settings.stirlingProbe"].exists)
        XCTAssertTrue(settingsApp.buttons["settings.forgetAll"].exists)
    }

    func testSettingsAppearanceLaunchSeamsExerciseSystemLightAndDark() throws {
        let cases = [("system", "System"), ("light", "Light"), ("dark", "Dark")]

        for (mode, label) in cases {
            let appearanceApp = XCUIApplication()
            appearanceApp.launchArguments = [
                "-ui-testing",
                "-ui-testing-settings",
                "-ui-testing-appearance-\(mode)"
            ]
            appearanceApp.launch()

            XCTAssertTrue(appearanceApp.windows.firstMatch.waitForExistence(timeout: 5))
            let value = appearanceApp.staticTexts["settings.appearanceValue"]
            XCTAssertTrue(value.waitForExistence(timeout: 3))
            XCTAssertEqual(value.label, "Current preview: \(label) appearance")
            appearanceApp.terminate()
        }
    }

    func testDeterministicImportFixtureReachesReview() throws {
        let importApp = XCUIApplication()
        importApp.launchArguments = ["-ui-testing", "-ui-testing-import"]
        importApp.launch()

        XCTAssertTrue(importApp.buttons["home.uiTestImportFixture"].waitForExistence(timeout: 5))
        importApp.buttons["home.uiTestImportFixture"].click()
        XCTAssertTrue(importApp.buttons["review.queue"].waitForExistence(timeout: 5))
    }

    func testDeterministicDeniedImportOffersRecovery() throws {
        let deniedApp = XCUIApplication()
        deniedApp.launchArguments = ["-ui-testing", "-ui-testing-import-denied"]
        deniedApp.launch()

        XCTAssertTrue(deniedApp.staticTexts["home.importPermissionDenied"].waitForExistence(timeout: 5))
        XCTAssertTrue(deniedApp.buttons["home.retryImport"].exists)
        deniedApp.buttons["home.retryImport"].click()
        XCTAssertTrue(deniedApp.buttons["review.queue"].waitForExistence(timeout: 5))
    }
}
