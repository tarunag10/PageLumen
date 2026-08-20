import XCTest
@testable import PageLumenCore

final class LocalModelPrototypeTests: XCTestCase {
    func testManifestValidationRejectsUnsafeMetadata() {
        let manifest = LocalModelPrototypeManifest(
            repositoryURL: URL(string: "http://example.com/model")!, revision: "",
            licenseIdentifier: "", modelCardURL: URL(string: "file:///model-card")!,
            weightsSizeBytes: 0, storageRelativePath: "../weights", supportsAppleSilicon: true
        )
        XCTAssertEqual(manifest.validate(), [
            .insecureRepositoryURL, .insecureModelCardURL,
            .emptyField("revision"), .emptyField("licenseIdentifier"),
            .invalidWeightsSize, .invalidStoragePath
        ])
    }

    func testPrototypeGateIsClosedUntilAllExplicitGatesPass() {
        let manifest = validManifest()
        let gate = LocalModelPrototypeGate()
        XCTAssertEqual(gate.decision(manifest: manifest, consentGranted: false,
                                     appleSiliconAvailable: true, removalPolicyConfigured: true,
                                     prototypeEnabled: true), .denied(.consentRequired))
        XCTAssertEqual(gate.decision(manifest: manifest, consentGranted: true,
                                     appleSiliconAvailable: true, removalPolicyConfigured: false,
                                     prototypeEnabled: true), .denied(.removalPolicyRequired))
        XCTAssertEqual(gate.decision(manifest: manifest, consentGranted: true,
                                     appleSiliconAvailable: true, removalPolicyConfigured: true,
                                     prototypeEnabled: false), .denied(.defaultPipelineDisabled))
        XCTAssertEqual(gate.decision(manifest: manifest, consentGranted: true,
                                     appleSiliconAvailable: true, removalPolicyConfigured: true,
                                     prototypeEnabled: true), .eligible)
    }

    func testUnsupportedAppleSiliconConfigurationFallsBack() {
        var manifest = validManifest()
        manifest = LocalModelPrototypeManifest(repositoryURL: manifest.repositoryURL,
                                                revision: manifest.revision,
                                                licenseIdentifier: manifest.licenseIdentifier,
                                                modelCardURL: manifest.modelCardURL,
                                                weightsSizeBytes: manifest.weightsSizeBytes,
                                                storageRelativePath: manifest.storageRelativePath,
                                                supportsAppleSilicon: true)
        XCTAssertEqual(LocalModelPrototypeGate().decision(manifest: manifest, consentGranted: true,
                                                          appleSiliconAvailable: false,
                                                          removalPolicyConfigured: true,
                                                          prototypeEnabled: true), .denied(.unsupportedDevice))
    }

    func testLifecycleRequiresConsentAndClampsProgress() {
        XCTAssertEqual(LocalModelLifecycle.startDownload(from: .unavailable, consentGranted: false), .awaitingConsent)
        let downloading = LocalModelLifecycle.startDownload(from: .unavailable, consentGranted: true)
        XCTAssertEqual(LocalModelLifecycle.updateProgress(2, from: downloading), .downloading(progress: 1))
    }

    func testLifecycleSupportsCancellationAndOfflineRemoval() {
        let downloading = LocalModelLifecycle.startDownload(from: .unavailable, consentGranted: true)
        XCTAssertEqual(LocalModelLifecycle.cancel(from: downloading), .cancelled)
        XCTAssertEqual(LocalModelLifecycle.removeOffline(from: .ready), .removed)
        XCTAssertEqual(LocalModelLifecycle.startDownload(from: .ready, consentGranted: true), .ready)
    }

    private func validManifest() -> LocalModelPrototypeManifest {
        LocalModelPrototypeManifest(repositoryURL: URL(string: "https://github.com/example/model")!,
                                     revision: "abc123", licenseIdentifier: "MIT",
                                     modelCardURL: URL(string: "https://example.com/model-card")!,
                                     weightsSizeBytes: 1024, storageRelativePath: "models/example",
                                     supportsAppleSilicon: false)
    }
}
