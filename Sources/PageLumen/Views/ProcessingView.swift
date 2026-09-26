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
                    VStack(alignment: .leading, spacing: 16) {
                        if store.batchQueue.failedCount > 0 && store.batchQueue.completedDocuments.isEmpty && !store.isProcessing {
                            recoveryBanner
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                            ForEach(activeDocument.pages) { page in
                                ProcessingPageCard(
                                    page: page,
                                    isDisabled: store.isProcessing || !store.canNavigate(to: .review),
                                    disabledHint: store.navigationAvailabilityMessage(to: .review)
                                ) {
                                    guard store.navigate(to: .review) else { return }
                                    store.selectedPageNumber = page.pageNumber
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView {
                    Label("Preparing Import", systemImage: "text.viewfinder")
                } description: {
                    Text(store.statusMessage)
                } actions: {
                    Button {
                        guard !store.isProcessing else { return }
                        store.openDocumentPanel()
                    } label: {
                        Label("Open Files", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isProcessing)
                    .help(store.isProcessing ? "Finish or cancel the current import first" : "Open another document")
                    .accessibilityIdentifier("processing.openFiles")
                    Button {
                        _ = store.navigate(to: .home)
                    } label: {
                        Text("Back to Add")
                    }
                    .disabled(!store.canNavigate(to: .home))
                    .help(store.navigationAvailabilityMessage(to: .home))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AccessibleStyle.appBackground)
    }

    private var recoveryBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Import needs attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AccessibleStyle.warning)
            Text("No file completed successfully. Review is unavailable until you retry with another file or processing option.")
                .font(.callout)
                .foregroundStyle(AccessibleStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    guard !store.isProcessing else { return }
                    store.openDocumentPanel()
                } label: {
                    Label("Open Files", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Button("Back to Add") {
                    _ = store.navigate(to: .home)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessiblePanel(paddedShadow: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("processing.recovery")
        .accessibilityAddTraits(.updatesFrequently)
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.statusMessage)
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Spacer()

            if store.isExportingAudio {
                Label("Audio export is running in Listen & Export", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .help("Audio export is separate from document processing.")
            }

            VStack(alignment: .trailing, spacing: 6) {
                ProgressView(value: pageProgress)
                    .frame(minWidth: 140, idealWidth: 200, maxWidth: 260)
                    .tint(AccessibleStyle.accentBright)
                    .accessibilityLabel("Processing progress")
                    .accessibilityValue(progressLabel)
                    .accessibilityIdentifier("processing.progress")

                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Button(role: .cancel) {
                store.cancelImport()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .disabled(!store.isProcessing || store.isExportingAudio)
            .help(store.isExportingAudio ? "Audio export is not cancelled from this screen" : "Cancel document import")
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
    let isDisabled: Bool
    let disabledHint: String
    let action: () -> Void
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(page.pageNumber), \(page.ocrStatus.statusDescriptor.label)")
        .accessibilityHint(isDisabled ? disabledHint : "Open this page in Review.")
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
