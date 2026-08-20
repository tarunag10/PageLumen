import Foundation
import SwiftUI
import PageLumenCore

/// Persisted presentation-only controls for the review and reading surfaces.
/// These values never modify extracted document content or export data.
struct ReadingPreferences: Equatable {
    enum Typography: String, CaseIterable, Identifiable {
        case system
        case serif
        case monospaced

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        func font(for blockType: BlockType? = nil) -> Font {
            switch self {
            case .system: return blockType == .heading ? .title3.weight(.semibold) : .body
            case .serif: return blockType == .heading ? .system(.title3, design: .serif).weight(.semibold) : .system(.body, design: .serif)
            case .monospaced: return blockType == .heading ? .system(.title3, design: .monospaced).weight(.semibold) : .system(.body, design: .monospaced)
            }
        }
    }

    static let focusModeKey = "reading.focusMode"
    static let lineSpacingKey = "reading.lineSpacing"
    static let typographyKey = "reading.typography"
    static let speechRateKey = "reading.speechRate"

    var focusMode = false
    var lineSpacing = 4.0
    var typography: Typography = .system
    var speechRate = 0.92

    static func load(from defaults: UserDefaults = .standard) -> ReadingPreferences {
        var result = ReadingPreferences()
        result.focusMode = defaults.object(forKey: focusModeKey) as? Bool ?? result.focusMode
        result.lineSpacing = defaults.object(forKey: lineSpacingKey) as? Double ?? result.lineSpacing
        if let raw = defaults.string(forKey: typographyKey), let value = Typography(rawValue: raw) {
            result.typography = value
        }
        result.speechRate = defaults.object(forKey: speechRateKey) as? Double ?? result.speechRate
        return result.normalized
    }

    func persist(to defaults: UserDefaults = .standard) {
        let value = normalized
        defaults.set(value.focusMode, forKey: Self.focusModeKey)
        defaults.set(value.lineSpacing, forKey: Self.lineSpacingKey)
        defaults.set(value.typography.rawValue, forKey: Self.typographyKey)
        defaults.set(value.speechRate, forKey: Self.speechRateKey)
    }

    var normalized: ReadingPreferences {
        var result = self
        result.lineSpacing = min(max(lineSpacing, 0), 24)
        result.speechRate = min(max(speechRate, 0.5), 1.5)
        return result
    }
}
