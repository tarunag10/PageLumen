import AppKit
import PageLumenCore
import SwiftUI

struct PreviewPane: View {
    let page: ReaderPage?
    let showReadingOrder: Bool
    // Re-render when the high-contrast toggle changes so AccessibleStyle tokens
    // (border, selected, panelBackground, appBackground) pick up the new value.
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        ZStack {
            if let page {
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        PreviewImage(data: page.thumbnailData)
                            .frame(width: 360, height: 470)
                            .background(AccessibleStyle.panelBackground, in: RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius))
                            .overlay {
                                RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius)
                                    .stroke(AccessibleStyle.border)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 14, y: 6)

                        if showReadingOrder {
                            ReadingOrderOverlay(page: page)
                                .frame(width: 360, height: 470)
                        }
                    }
                    .padding(28)
                }
            } else {
                ContentUnavailableView("No Page Selected", systemImage: "doc.text.magnifyingglass")
            }
        }
        .background(AccessibleStyle.appBackground)
    }
}

private struct PreviewImage: View {
    let data: Data?

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
        } else {
            VStack(spacing: 12) {
                // Font is intentionally fixed for layout reasons — this is a
                // hero placeholder icon whose visual weight should not change
                // with text-size settings.
                Image(systemName: "doc.text.image")
                    .font(.system(size: 48))
                    .foregroundStyle(AccessibleStyle.tertiaryText)
                Text("Source preview")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }
        }
    }
}

private struct ReadingOrderOverlay: View {
    let page: ReaderPage
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        GeometryReader { proxy in
            ForEach(page.blocks) { block in
                let rect = scaled(block.bounds, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AccessibleStyle.accentBright, lineWidth: 2)
                        .background(AccessibleStyle.accent.opacity(0.08))
                    Text("\(block.readingOrderIndex + 1)")
                        .font(.caption2.bold())
                        .padding(5)
                        .background(AccessibleStyle.accentGradient, in: Circle())
                        .foregroundStyle(.white)
                        .offset(x: -8, y: -8)
                }
                .frame(width: max(rect.width, 24), height: max(rect.height, 20))
                .position(x: rect.midX, y: rect.midY)
                .accessibilityElement()
                .accessibilityLabel("Block \(block.readingOrderIndex + 1)")
                .accessibilityValue(block.text.prefix(80))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reading order overlay, \(page.blocks.count) blocks")
    }

    private func scaled(_ bounds: BoundingBox, in size: CGSize) -> CGRect {
        guard page.size.width > 0, page.size.height > 0 else {
            return .zero
        }
        let xScale = size.width / page.size.width
        let yScale = size.height / page.size.height
        return CGRect(
            x: bounds.x * xScale,
            y: bounds.y * yScale,
            width: bounds.width * xScale,
            height: bounds.height * yScale
        )
    }
}
