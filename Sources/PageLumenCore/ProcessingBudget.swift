import Foundation

/// The user-selectable trade-off made before a document enters the bounded
/// processing pipeline. The default remains full quality and all pages.
public enum ProcessingQuality: String, CaseIterable, Codable, Sendable {
    case full
    case balanced
    case fast

    public var displayName: String {
        switch self {
        case .full: return "Full quality"
        case .balanced: return "Balanced quality"
        case .fast: return "Fast, lower quality"
        }
    }

    /// A multiplier applied to the normal OCR render target. It never permits
    /// the pixel safety cap to be exceeded.
    public var renderScaleMultiplier: CGFloat {
        switch self {
        case .full: return 1
        case .balanced: return 0.75
        case .fast: return 0.5
        }
    }
}

public struct ProcessingImportOptions: Equatable, Sendable {
    public var quality: ProcessingQuality
    public var pageRange: ClosedRange<Int>?

    public init(quality: ProcessingQuality = .full, pageRange: ClosedRange<Int>? = nil) {
        self.quality = quality
        self.pageRange = pageRange
    }

    public static let full = Self()
}

/// A conservative, deterministic estimate. This is intentionally not a claim
/// about resident memory: allocator behaviour and device pressure require a
/// physical-device measurement gate.
public struct ProcessingBudgetEstimate: Equatable, Sendable {
    public let pageCount: Int
    public let selectedPageCount: Int
    public let totalPixels: UInt64
    public let peakPagePixels: UInt64
    public let estimatedPeakMemoryBytes: UInt64
    public let exceedsPixelBudget: Bool
    public let exceedsMemoryBudget: Bool

    public var requiresChoice: Bool {
        exceedsPixelBudget || exceedsMemoryBudget || pageCount > 100 && selectedPageCount == pageCount
    }

    public var summary: String {
        let memory = ByteCountFormatter.string(fromByteCount: Int64(min(estimatedPeakMemoryBytes, UInt64(Int64.max))), countStyle: .memory)
        return "\(selectedPageCount) page\(selectedPageCount == 1 ? "" : "s"), \(memory) estimated peak working memory"
    }
}

public enum ProcessingBudgetEstimator {
    public static let maxPagePixels: UInt64 = 50_000_000
    public static let estimatedMemoryBudgetBytes: UInt64 = 512 * 1_024 * 1_024

    /// Estimates rendered pixels and three transient 8-bit buffers per page.
    /// The multiplier is deliberately conservative and stable for tests.
    public static func estimate(
        pageSizes: [(width: Double, height: Double)],
        options: ProcessingImportOptions = .full
    ) -> ProcessingBudgetEstimate {
        let pageCount = pageSizes.count
        let selectedIndices: [Int]
        if let range = options.pageRange {
            selectedIndices = pageSizes.indices.filter { range.contains($0 + 1) }
        } else {
            selectedIndices = Array(pageSizes.indices)
        }
        let scale = Double(options.quality.renderScaleMultiplier)
        let pixels = pageSizes.map { size in
            let width = max(1, Int(ceil(size.width * 2 * scale)))
            let height = max(1, Int(ceil(size.height * 2 * scale)))
            return UInt64(width) * UInt64(height)
        }
        let selectedPixels = selectedIndices.map { pixels[$0] }
        let totalPixels = selectedPixels.reduce(0, +)
        let peakPagePixels = selectedPixels.max() ?? 0
        let estimatedPeakMemoryBytes = peakPagePixels.multipliedReportingOverflow(by: 4 * 3).partialValue
        return ProcessingBudgetEstimate(
            pageCount: pageCount,
            selectedPageCount: selectedIndices.count,
            totalPixels: totalPixels,
            peakPagePixels: peakPagePixels,
            estimatedPeakMemoryBytes: estimatedPeakMemoryBytes,
            exceedsPixelBudget: selectedPixels.contains { $0 > maxPagePixels },
            exceedsMemoryBudget: estimatedPeakMemoryBytes > estimatedMemoryBudgetBytes
        )
    }
}
