import PageLumenCore
import SwiftUI

public struct StatusDescriptor: Sendable {
    public let label: String
    public let systemImage: String
    public let tint: Color
}

public extension OCRStatus {
    var statusDescriptor: StatusDescriptor {
        switch self {
        case .pending:
            return StatusDescriptor(label: "Pending", systemImage: "circle", tint: AccessibleStyle.secondaryText)
        case .processing:
            return StatusDescriptor(label: "OCR", systemImage: "text.viewfinder", tint: AccessibleStyle.accentBright)
        case .complete:
            return StatusDescriptor(label: "Done", systemImage: "checkmark.circle.fill", tint: AccessibleStyle.success)
        case .failed:
            return StatusDescriptor(label: "Failed", systemImage: "exclamationmark.triangle.fill", tint: AccessibleStyle.warning)
        }
    }
}

public extension BatchImportItemStatus {
    var statusDescriptor: StatusDescriptor {
        switch self {
        case .pending:
            return StatusDescriptor(label: "Pending", systemImage: "circle", tint: AccessibleStyle.secondaryText)
        case .processing:
            return StatusDescriptor(label: "Processing", systemImage: "hourglass", tint: AccessibleStyle.accentBright)
        case .complete:
            return StatusDescriptor(label: "Complete", systemImage: "checkmark.circle.fill", tint: AccessibleStyle.success)
        case .cancelled:
            return StatusDescriptor(label: "Cancelled", systemImage: "xmark.circle", tint: AccessibleStyle.secondaryText)
        case .failed:
            return StatusDescriptor(label: "Failed", systemImage: "exclamationmark.triangle.fill", tint: AccessibleStyle.warning)
        }
    }
}
