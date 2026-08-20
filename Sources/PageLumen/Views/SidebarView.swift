import PageLumenCore
import SwiftUI

struct SidebarView: View {
    @Environment(DocumentStore.self) private var store
    @State private var documentToForget: ReaderDocument?
    @State private var librarySearchField = ""
    @AppStorage(DocumentRepositorySettings.keepSearchableLocalCopiesKey) private var keepSearchableLocalCopies = false
    // Re-render when the high-contrast toggle changes so AccessibleStyle tokens
    // (border, elevatedBackground) pick up the new value.
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            SidebarHeader()

            List(selection: $store.selectedDestination) {
                Section("Steps") {
                    SidebarRow(title: "1. Add Document", systemImage: "tray.and.arrow.down", tag: DocumentStore.Destination.home)
                    SidebarRow(title: "2. Process", systemImage: "text.viewfinder", tag: DocumentStore.Destination.processing)
                    SidebarRow(title: "3. Review Text", systemImage: "rectangle.split.2x1", tag: DocumentStore.Destination.review)
                    SidebarRow(title: "4. Listen & Export", systemImage: "square.and.arrow.up", tag: DocumentStore.Destination.summaryExport)
                }

                if !store.batchQueue.items.isEmpty {
                    Section("Batch") {
                        ForEach(store.batchQueue.items) { item in
                            Button {
                                store.selectBatchItem(item)
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: item.status.statusDescriptor.systemImage)
                                        .foregroundStyle(item.status.statusDescriptor.tint)
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 22, height: 22)
                                        .background(item.status.statusDescriptor.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.fileName)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(AccessibleStyle.primaryText)
                                            .lineLimit(1)

                                        Text(detail(for: item))
                                            .font(.caption2)
                                            .foregroundStyle(AccessibleStyle.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(item.document == nil)
                            .accessibilityLabel("\(item.fileName), \(detail(for: item))")
                            .accessibilityHint(item.document == nil ? "This file is not available to review." : "Open this imported document in Review.")
                        }
                    }
                }

                if !store.recentDocuments.isEmpty {
                    Section("Most recent") {
                        librarySearchFieldView(store: store)
                        if let mostRecent = store.recentDocuments.first {
                            recentDocumentRow(mostRecent, subtitle: lastOpenedLabel(for: mostRecent))
                        }
                    }

                    if store.recentDocuments.count > 1 {
                        Section("Library") {
                            ForEach(store.recentDocuments.dropFirst()) { document in
                                Button {
                                    store.selectRecentDocument(document)
                                } label: {
                                    HStack(spacing: 11) {
                                        Image(systemName: document.processingStatus == .complete ? "checkmark.circle" : "doc.text.magnifyingglass")
                                            .foregroundStyle(document.processingStatus == .complete ? AccessibleStyle.success : AccessibleStyle.secondaryText)
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(width: 22, height: 22)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(document.title)
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(AccessibleStyle.primaryText)
                                                .lineLimit(1)

                                            Text(librarySubtitle(for: document))
                                                .font(.caption2)
                                                .foregroundStyle(AccessibleStyle.secondaryText)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Forget Recent Document", role: .destructive) {
                                        documentToForget = document
                                    }
                                }
                                .accessibilityLabel("\(document.title), \(librarySubtitle(for: document))")
                                .accessibilityHint("Open this document in Review.")
                            }
                        }
                    }

                    if !store.librarySearchResults.isEmpty {
                        Section("Search results") {
                            ForEach(store.librarySearchResults) { result in
                                Button {
                                    store.openLibrarySearchResult(result)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.callout.weight(.medium))
                                            .lineLimit(1)
                                        Text("Page \(result.pageNumber) • \(result.snippet)")
                                            .font(.caption2)
                                            .foregroundStyle(AccessibleStyle.secondaryText)
                                            .lineLimit(2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(result.title), page \(result.pageNumber)")
                                .accessibilityHint("Open this local-library search result in Review.")
                            }
                        }
                    }
                }

                Section("Outline") {
                    if store.document.outline.isEmpty {
                        Text("Headings appear here after import")
                            .font(.callout)
                            .foregroundStyle(AccessibleStyle.tertiaryText)
                    } else {
                        ForEach(store.document.outline) { item in
                            Button {
                                store.selectedPageNumber = item.pageNumber
                                store.selectedDestination = .review
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: "textformat.size")
                                        .foregroundStyle(AccessibleStyle.secondaryText)
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 22, height: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(AccessibleStyle.primaryText)
                                            .lineLimit(1)
                                        Text("Page \(item.pageNumber)")
                                            .font(.caption2)
                                            .foregroundStyle(AccessibleStyle.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Heading \(item.title), page \(item.pageNumber)")
                            .accessibilityHint("Open this heading in Review.")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AccessibleStyle.appBackground)
            .liquidGlassIfAvailable(boostContrast: boostContrast)
        }
        .background(AccessibleStyle.appBackground)
        .onChange(of: keepSearchableLocalCopies) { _, enabled in
            if !enabled {
                librarySearchField = ""
                store.librarySearchResults = []
            }
        }
        .safeAreaInset(edge: .bottom) {
            SidebarStatusFooter(
                title: store.document.title,
                status: store.statusMessage
            )
        }
        .confirmationDialog(
            "Forget recent document?",
            isPresented: Binding(
                get: { documentToForget != nil },
                set: { if !$0 { documentToForget = nil } }
            ),
            titleVisibility: .visible,
            presenting: documentToForget
        ) { document in
            Button("Forget \(document.title)", role: .destructive) {
                store.forgetRecentDocument(document)
                documentToForget = nil
            }
            Button("Cancel", role: .cancel) {
                documentToForget = nil
            }
        } message: { document in
            Text("This removes the retained PageLumen copy. The original source file at \(document.sourceURL?.path ?? "its original location") is not deleted.")
        }
    }

    @ViewBuilder
    private func librarySearchFieldView(store: DocumentStore) -> some View {
        TextField("Search local library", text: $librarySearchField)
            .textFieldStyle(.roundedBorder)
            .accessibilityHint("Searches retained OCR text only when searchable local copies are enabled in Settings")
            .onSubmit {
                store.searchLibrary(query: librarySearchField)
            }
            .onChange(of: librarySearchField) { _, value in
                store.searchLibrary(query: value)
            }
            .disabled(!keepSearchableLocalCopies)
    }

    private func detail(for item: BatchImportItem) -> String {
        switch item.status {
        case .failed(let message):
            return message
        default:
            return item.status.label
        }
    }

    private func lastOpenedLabel(for document: ReaderDocument) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let when = formatter.localizedString(for: document.createdAt, relativeTo: Date())
        return "Opened \(when) • \(document.pageCount) page\(document.pageCount == 1 ? "" : "s")"
    }

    private func librarySubtitle(for document: ReaderDocument) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: document.createdAt)
        return "\(dateString) • \(document.pageCount) page\(document.pageCount == 1 ? "" : "s")"
    }

    private func recentDocumentRow(_ document: ReaderDocument, subtitle: String) -> some View {
        Button {
            store.selectRecentDocument(document)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: document.processingStatus == .complete ? "checkmark.circle" : "doc.text.magnifyingglass")
                    .foregroundStyle(document.processingStatus == .complete ? AccessibleStyle.success : AccessibleStyle.secondaryText)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AccessibleStyle.primaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Forget Recent Document", role: .destructive) {
                documentToForget = document
            }
        }
        .accessibilityLabel("\(document.title), \(subtitle)")
        .accessibilityHint("Open this document in Review.")
    }
}

private struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(AccessibleStyle.accentGradient)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(AccessibleStyle.accentBright.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: AccessibleStyle.accent.opacity(0.4), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 0) {
                Text("PageLumen")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AccessibleStyle.primaryText)
                Text("Accessible Document Reader")
                    .font(.caption2)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(AccessibleStyle.elevatedBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AccessibleStyle.border)
                .frame(height: 1)
        }
    }
}

private struct SidebarRow: View {
    @Environment(DocumentStore.self) private var store
    let title: String
    let systemImage: String
    let tag: DocumentStore.Destination

    var body: some View {
        Label(title, systemImage: systemImage)
            .tag(tag)
            .font(.callout.weight(.medium))
            .disabled(!store.canNavigate(to: tag))
            .accessibilityLabel(title)
            .accessibilityValue(store.canNavigate(to: tag) ? "Available" : "Unavailable until a document is imported")
    }
}

private struct SidebarStatusFooter: View {
    let title: String
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AccessibleStyle.success)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AccessibleStyle.primaryText)
                    .lineLimit(1)
            }
            Text(status)
                .font(.caption2)
                .foregroundStyle(AccessibleStyle.secondaryText)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AccessibleStyle.elevatedBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AccessibleStyle.border)
                .frame(height: 1)
        }
    }
}
