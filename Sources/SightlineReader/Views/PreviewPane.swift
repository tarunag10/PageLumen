import AppKit
import SightlineCore
import SwiftUI

struct PreviewPane: View {
    let page: ReaderPage?
    let showReadingOrder: Bool

    var body: some View {
        ZStack {
            if let page {
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        PreviewImage(data: page.thumbnailData)
                            .frame(width: 360, height: 470)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.secondary.opacity(0.18))
                            }

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
        .background(.background)
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
                Image(systemName: "doc.text.image")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Source preview")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReadingOrderOverlay: View {
    let page: ReaderPage

    var body: some View {
        GeometryReader { proxy in
            ForEach(page.blocks) { block in
                let rect = scaled(block.bounds, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .background(Color.accentColor.opacity(0.08))
                    Text("\(block.readingOrderIndex + 1)")
                        .font(.caption2.bold())
                        .padding(4)
                        .background(Color.accentColor, in: Circle())
                        .foregroundStyle(.white)
                        .offset(x: -6, y: -6)
                }
                .frame(width: max(rect.width, 24), height: max(rect.height, 20))
                .position(x: rect.midX, y: rect.midY)
            }
        }
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
