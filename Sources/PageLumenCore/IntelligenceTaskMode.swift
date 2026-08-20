import Foundation

/// Explicit, bounded intelligence operations exposed by the product.  Keeping
/// these as a closed set prevents a future chat surface from silently turning
/// the entire library into model context.
public enum IntelligenceTaskMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case summarizeSelection
    case explainTable
    case describeFigure
    case studyNotes
    case comparePassages

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .summarizeSelection: return "Summarise selection"
        case .explainTable: return "Explain table"
        case .describeFigure: return "Describe figure"
        case .studyNotes: return "Create study notes"
        case .comparePassages: return "Compare passages"
        }
    }
}

/// Builds the extra instruction for the two document-text modes which are not
/// simple summaries.  The caller still supplies the bounded context produced
/// by `IntelligenceContextBuilder.summary`; no additional source is fetched.
public enum IntelligenceTaskPrompt {
    public static func instruction(for mode: IntelligenceTaskMode) -> String {
        switch mode {
        case .studyNotes:
            return "Create concise study notes with a title, key terms, numbered ideas, and a short set of review questions. Cite the provided source block IDs after each idea. Do not add facts not present in the source."
        case .comparePassages:
            return "Compare only the provided passages. Separate agreements, differences, and unresolved uncertainty. Cite the source page and block IDs for every comparison; never infer a difference from omitted content."
        case .summarizeSelection:
            return "Summarize only the provided source blocks and cite each material claim."
        case .explainTable:
            return "Explain only the provided table and preserve its uncertainty."
        case .describeFigure:
            return "Describe only the provided figure and preserve its uncertainty."
        }
    }

    public static func prompt(mode: IntelligenceTaskMode, context: BoundedIntelligenceContext) -> String {
        instruction(for: mode) + "\n\n" + context.prompt
    }
}
