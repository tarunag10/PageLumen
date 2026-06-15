import SwiftUI
import TipKit

struct DropZoneTip: Tip {
    var title: Text { Text("Drop a PDF, image, or screenshot") }
    var message: Text { Text("PageLumen reads it locally — no upload.") }
    var image: Image? { Image(systemName: "doc.viewfinder") }
}

struct ReviewIssueTip: Tip {
    var title: Text { Text("Press ⌘⇧R to jump to the first review issue") }
    var message: Text { Text("VoiceOver will read each issue in order. Press ⌘⇧↩ to mark a page reviewed.") }
    var image: Image? { Image(systemName: "scope") }
}

struct ExportAccessibilityTip: Tip {
    var title: Text { Text("Tagged HTML and Accessibility Report are review-ready") }
    var message: Text { Text("These formats include semantic structure for screen readers. Other formats are also accessible but do not include the audit metadata.") }
    var image: Image? { Image(systemName: "checkmark.seal") }
}

struct BoostContrastTip: Tip {
    var title: Text { Text("If text is hard to read, try Boost Contrast") }
    var message: Text { Text("Settings > Display has a toggle that swaps panel colors for higher-contrast alternates.") }
    var image: Image? { Image(systemName: "circle.lefthalf.filled") }
}
