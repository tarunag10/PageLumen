import AppKit
import PageLumenCore
import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject private var store: DocumentStore
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 14)], spacing: 14) {
                        ForEach(activeDocument.pages) { page in
                            ProcessingPageCard(page: page)
                        }
                    }
                    .padding(20)
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
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text(store.statusMessage)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                ProgressView(value: pageProgress)
                    .frame(width: 180)

                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            Button(role: .cancel) {
                store.cancelImport()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .disabled(!store.isProcessing)
        }
        .padding(20)
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
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)

                thumbnail
                    .padding(10)
            }
            .aspectRatio(0.74, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                statusBadge
                    .padding(8)
            }

            HStack(spacing: 8) {
                Text("Page \(page.pageNumber)")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Label(page.ocrStatus.statusDescriptor.label, systemImage: page.ocrStatus.statusDescriptor.systemImage)
                    .font(.caption)
                    .foregroundStyle(page.ocrStatus.statusDescriptor.tint)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(12)
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
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AccessibleStyle.border)
                }
        } else {
            VStack(spacing: 8) {
                // Font is intentionally fixed for layout reasons — this is a
                // thumbnail placeholder icon whose visual weight should not
                // change with text-size settings.
                Image(systemName: "doc.text.image")
                    .font(.system(size: 30))
                Text("Thumbnail pending")
                    .font(.caption)
            }
            .foregroundStyle(.primary)
        }
    }

    private var statusBadge: some View {
        Group {
            if page.ocrStatus == .processing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: page.ocrStatus.statusDescriptor.systemImage)
                    .foregroundStyle(page.ocrStatus.statusDescriptor.tint)
            }
        }
        .frame(width: 24, height: 24)
        .background(AccessibleStyle.panelBackground, in: Circle())
        .overlay {
            Circle()
                .stroke(AccessibleStyle.border)
        }
    }
}
