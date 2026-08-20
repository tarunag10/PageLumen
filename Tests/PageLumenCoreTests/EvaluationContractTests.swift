import XCTest
@testable import PageLumenCore

final class EvaluationContractTests: XCTestCase {
    private func manifest(consentSeparated: Bool = true) -> EvaluationContract.CorpusManifest {
        let consent = EvaluationContract.Consent(
            consentVersion: "consent-v1",
            status: .pending,
            purpose: "Offline quality evaluation only",
            collectionScope: "Synthetic and separately consented evaluation documents",
            retentionPolicy: "Delete after the approved evaluation window",
            withdrawalProcess: "Remove the participant record and exclude future runs",
            productDocumentsExcluded: consentSeparated
        )
        let samples = EvaluationContract.requiredAdversarialTags.sorted().enumerated().map { index, tag in
            EvaluationContract.Sample(
                id: "sample-\(index)", className: tag, sensitivity: tag.contains("sensitive") ? "restricted" : "synthetic",
                language: tag == "multilingual" ? "en-hi" : "en",
                adversarialTags: [tag], groundTruthStatus: "not-collected",
                sourceReference: "evaluation-fixture-\(index)"
            )
        }
        return EvaluationContract.CorpusManifest(corpusID: "pagelumen-ai-evaluation", revision: "v1", consent: consent, samples: samples)
    }

    func testVersionedManifestIsSeparatedAndCoversAdversarialClasses() {
        let value = manifest()
        XCTAssertEqual(value.schemaVersion, 1)
        XCTAssertTrue(EvaluationContract.validate(value).isEmpty)
    }

    func testValidationRejectsProductReferencesDuplicateIDsAndMissingTags() {
        let base = manifest()
        let first = base.samples[0]
        let badSample = EvaluationContract.Sample(
            id: first.id, className: first.className, sensitivity: first.sensitivity,
            language: first.language, adversarialTags: [first.className],
            groundTruthStatus: first.groundTruthStatus, sourceReference: "/Users/me/product-document.pdf"
        )
        let samples = [badSample] + base.samples.dropFirst().filter { !$0.adversarialTags.contains("hidden-text") }
        let bad = EvaluationContract.CorpusManifest(corpusID: base.corpusID, revision: base.revision, consent: base.consent, samples: samples)
        let errors = EvaluationContract.validate(bad)
        XCTAssertTrue(errors.contains(.duplicateID(first.id)))
        XCTAssertTrue(errors.contains(.productDocumentReference(first.id)))
        XCTAssertTrue(errors.contains(.missingAdversarialTag("hidden-text")))
    }

    func testUnavailableScaffoldCannotClaimScores() {
        let corpus = manifest()
        let report = EvaluationContract.Report(
            corpusRevision: corpus.revision,
            run: nil,
            metrics: [EvaluationContract.MetricResult(metricID: "citation-precision", status: .unavailable, value: nil, unavailableReason: "No consented run yet")]
        )
        XCTAssertTrue(EvaluationContract.validate(report, against: corpus).isEmpty)

        let fabricated = EvaluationContract.Report(
            corpusRevision: corpus.revision,
            run: nil,
            metrics: [EvaluationContract.MetricResult(metricID: "citation-precision", status: .unavailable, value: 1, unavailableReason: nil)]
        )
        let errors = EvaluationContract.validate(fabricated, against: corpus)
        XCTAssertTrue(errors.contains(.unavailableMetricHasValue("citation-precision")))
        XCTAssertTrue(errors.contains(.missingUnavailableReason("citation-precision")))
    }

    func testMeasuredMetricRequiresVersionedRunMetadata() {
        let corpus = manifest()
        let report = EvaluationContract.Report(
            corpusRevision: corpus.revision,
            run: nil,
            metrics: [EvaluationContract.MetricResult(metricID: "latency", status: .measured, value: 120, unavailableReason: nil)]
        )
        XCTAssertTrue(EvaluationContract.validate(report, against: corpus).contains(.measuredValueWithoutRun("latency")))
    }
}
