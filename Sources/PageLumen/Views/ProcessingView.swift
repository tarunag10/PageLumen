import AppKit
import PageLumenCore
import SwiftUI

struct ProcessingView: View {
    @Environment(DocumentStore.self) private var store
    // Re-render when the high-contrast toggle changes so AccessibleStyle tokens
    // (border, panelBackground) pick up the new value.
    @AppStorage("boostContrast") private var boostContrast = false

    private var activeDocument: ReaderDocument? {
        store.processingDocument
    }

    private var pageProgress: Double {
        guard let document = activeDocument, !document.pages.isEmpty else {
            return store.batchQueue.totalCount == 0
                ? 0
                : Double(store.batchQueue.completedCount) / Double(store.batchQueue.totalCount)
        }

        let units = document.pages.reduce(0.0) { total, page in
            switch page.ocrStatus {
            case .pending:
                return total
            case .processing:
                return total + 0.5
            case .complete:
                return total + 1.0
            case .failed:
                return total + 1.0
            }
        }
        return units / Double(document.pages.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let activeDocument {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                        ForEach(activeDocument.pages) { page in
                            ProcessingPageCard(page: page)
                        }
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView {
                    Label("Preparing Import", systemImage: "text.viewfinder")
                } description: {
                    Text(store.statusMessage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AccessibleStyle.appBackground)
    }

    private var header: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AccessibleStyle.accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AccessibleStyle.accentBright)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AccessibleStyle.primaryText)
                    .lineLimit(1)

                Text(store.statusMessage)
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                ProgressView(value: pageProgress)
                    .frame(width: 200)
                    .tint(AccessibleStyle.accentBright)

                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Button(role: .cancel) {
                store.cancelImport()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .disabled(!store.isProcessing)
        }
        .padding(22)
        .accessibleToolbarSurface()
    }

    private var title: String {
        if let document = activeDocument {
            return document.title
        }
        if !store.processingFileName.isEmpty {
            return store.processingFileName
        }
        return store.isProcessing ? "Processing document" : "Processing"
    }

    private var progressLabel: String {
        if let document = activeDocument {
            let completed = document.pages.filter { $0.ocrStatus == .complete || $0.ocrStatus == .failed }.count
            return "\(completed) of \(document.pages.count) pages"
        }
        return "\(store.batchQueue.completedCount) of \(store.batchQueue.totalCount) files"
    }
}

private struct ProcessingPageCard: View {
    let page: ReaderPage
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius)
                    .fill(AccessibleStyle.elevatedBackground)

                thumbnail
                    .padding(10)
            }
            .aspectRatio(0.74, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                statusBadge
                    .padding(10)
            }

            HStack(spacing: 8) {
                Text("Page \(page.pageNumber)")
                    .font(.headline)
                    .foregroundStyle(AccessibleStyle.primaryText)
                    .lineLimit(1)

                Spacer()

                Label(page.ocrStatus.statusDescriptor.label, systemImage: page.ocrStatus.statusDescriptor.systemImage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(page.ocrStatus.statusDescriptor.tint)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(14)
        .accessiblePanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(page.pageNumber), \(page.ocrStatus.statusDescriptor.label)")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = page.thumbnailData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AccessibleStyle.border)
                }
        } else {
            VStack(spacing: 8) {
                // Font is intentionally fixed for layout reasons — this is a
                // thumbnail placeholder icon whose visual weight should not
                // change with text-size settings.
                Image(systemName: "doc.text.image")
                    .font(.system(size: 30))
                    .foregroundStyle(AccessibleStyle.tertiaryText)
                Text("Thumbnail pending")
                    .font(.caption)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }
        }
    }

    private var statusBadge: some View {
        Group {
            if page.ocrStatus == .processing {
                ProgressView()
                    .controlSize(.small)
                    .tint(AccessibleStyle.accentBright)
            } else {
                Image(systemName: page.ocrStatus.statusDescriptor.systemImage)
                    .foregroundStyle(page.ocrStatus.statusDescriptor.tint)
            }
        }
        .frame(width: 26, height: 26)
        .background(AccessibleStyle.floatingBackground, in: Circle())
        .overlay {
            Circle()
                .stroke(AccessibleStyle.border)
        }
    }
}
