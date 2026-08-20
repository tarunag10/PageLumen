import Foundation

/// Explicit consent modes for generative assistance. The downloaded-model mode
/// is reserved for a future opt-in integration and is never treated as
/// available by the current Foundation Models adapter.
public enum IntelligenceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    case appleFoundationModels
    case downloadedLocalModel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .appleFoundationModels: return "Apple Foundation Models"
        case .downloadedLocalModel: return "Downloaded local model (future)"
        }
    }
}
