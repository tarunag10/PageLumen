import Foundation

/// The accessibility dimensions that must be exercised for every release
/// candidate.  This is a deterministic release-planning contract, not a claim
/// that a unit test can replace a VoiceOver or physical-device session.
public enum AccessibilityVerificationDimension: String, CaseIterable, Codable, Sendable {
    case voiceOver
    case keyboard
    case appearance
    case contrast
    case textSize
    case motion
    case transparency

    public var systemSetting: String {
        switch self {
        case .voiceOver: return "VoiceOver"
        case .keyboard: return "Full Keyboard Access"
        case .appearance: return "Light and Dark appearance"
        case .contrast: return "Increase Contrast"
        case .textSize: return "Larger Text"
        case .motion: return "Reduce Motion"
        case .transparency: return "Reduce Transparency"
        }
    }
}

public struct AccessibilityVerificationItem: Codable, Equatable, Sendable {
    public let dimension: AccessibilityVerificationDimension
    public let workflow: String
    public let expectedOutcome: String
    public let requiresParticipant: Bool

    public init(
        dimension: AccessibilityVerificationDimension,
        workflow: String,
        expectedOutcome: String,
        requiresParticipant: Bool = true
    ) {
        self.dimension = dimension
        self.workflow = workflow
        self.expectedOutcome = expectedOutcome
        self.requiresParticipant = requiresParticipant
    }
}

public enum AccessibilityVerificationPlan {
    /// Keep these items short and observable so a release owner can record a
    /// pass/fail result without retaining imported document content.
    public static let releaseItems: [AccessibilityVerificationItem] = [
        AccessibilityVerificationItem(
            dimension: .voiceOver,
            workflow: "Navigate Add, Process, Review, findings, editable blocks, and Export with the rotor.",
            expectedOutcome: "Labels, values, hints, focus order, and selected-block context are understandable."
        ),
        AccessibilityVerificationItem(
            dimension: .keyboard,
            workflow: "Complete Add → Process → Review → Export using Full Keyboard Access.",
            expectedOutcome: "Every action is reachable, focus remains visible, and review shortcuts wrap correctly."
        ),
        AccessibilityVerificationItem(
            dimension: .appearance,
            workflow: "Repeat the primary workflow in Light and Dark appearance.",
            expectedOutcome: "Text, status, selection, disabled, and focus states remain distinguishable."
        ),
        AccessibilityVerificationItem(
            dimension: .contrast,
            workflow: "Enable Increase Contrast and inspect panels, borders, status icons, and selection.",
            expectedOutcome: "Borders and state changes remain distinguishable without relying on colour alone."
        ),
        AccessibilityVerificationItem(
            dimension: .textSize,
            workflow: "Use Larger Text while opening Review Queue, editing a block, and exporting.",
            expectedOutcome: "Labels and controls remain readable, unclipped, and reachable."
        ),
        AccessibilityVerificationItem(
            dimension: .motion,
            workflow: "Enable Reduce Motion and repeat selection, review, and export transitions.",
            expectedOutcome: "No disorienting animation hides state or prevents completion."
        ),
        AccessibilityVerificationItem(
            dimension: .transparency,
            workflow: "Enable Reduce Transparency and inspect every major surface and focus treatment.",
            expectedOutcome: "Surfaces retain readable separation and focus remains visible."
        )
    ]
}
