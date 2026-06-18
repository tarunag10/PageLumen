import AppKit
import TipKit
import UniformTypeIdentifiers
import SwiftUI

struct HomeView: View {
    @Environment(DocumentStore.self) private var store
    @State private var isTargeted = false
    // Re-render when the high-contrast toggle changes so AccessibleStyle.border
    // and AccessibleStyle.panelBackground pick up the new value.
    @AppStorage("boostContrast") private var boostContrast = false
    // ScaledMetric keeps the step pill numbers and InfoTile circles readable
    // when the user increases text size. The base 22 pt stays the default at
    // standard accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var stepCircleSize: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroSection
                dropZone
                stepCards
            }
            .padding(36)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AccessibleStyle.ambientGradient.ignoresSafeArea())
        .liquidGlassIfAvailable(boostContrast: boostContrast)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("STEP 1")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AccessibleStyle.accentBright)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AccessibleStyle.accentTint, in: Capsule())
            }

            Text("Add a document")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AccessibleStyle.primaryText)

            Text("Choose a PDF, screenshot, scan, slide, or image. PageLumen will extract text locally, build a reading order, and send you to review.")
                .font(.title3)
                .foregroundStyle(AccessibleStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AccessibleStyle.accent.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 8)
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(AccessibleStyle.accentGradient)
            }

            VStack(spacing: 6) {
                Text("Drop a file here")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AccessibleStyle.primaryText)
                Text("Works with PDF, PNG, JPEG, TIFF, and HEIC. You can also import multiple files at once.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    store.openDocumentPanel()
                } label: {
                    Label("Open Files", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o", modifiers: [.command])

                Button {
                    store.pasteImageFromClipboard()
                } label: {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                }

                Menu {
                    Button("Capture Selected Region") {
                        store.captureSelectedRegion()
                    }

                    Button("Capture Current Window") {
                        store.captureWindow()
                    }
                } label: {
                    Label("Capture Screen", systemImage: "camera.viewfinder")
                }

                Button {
                    store.loadSample()
                } label: {
                    Label("Try Demo", systemImage: "play.circle")
                }
            }
        }
        .popoverTip(DropZoneTip(), arrowEdge: .top)
        .frame(maxWidth: .infinity, minHeight: 320)
        .background {
            Group {
                if AccessibleStyle.boostContrast {
                    AccessibleStyle.panelBackground
                } else {
                    AccessibleStyle.heroGradient
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                .stroke(
                    isTargeted ? AccessibleStyle.accentBright : AccessibleStyle.border,
                    style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, dash: [10, 7])
                )
        }
        .shadow(
            color: .black.opacity(isTargeted ? 0.45 : 0.25),
            radius: isTargeted ? 24 : 14,
            y: isTargeted ? 10 : 6
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document import drop zone")
        .accessibilityHint("Drop supported files here, or use the Open Files, Paste Image, Capture Screen, or Try Demo buttons.")
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()

            for provider in providers {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    defer { group.leave() }
                    guard let data,
                          let string = String(data: data, encoding: .utf8),
                          let url = URL(string: string) else {
                        return
                    }
                    urls.append(url)
                }
            }

            group.notify(queue: .main) {
                store.startImport(urls: urls)
                announceDropResult(count: urls.count)
            }

            return true
        }
    }

    private var stepCards: some View {
        HStack(spacing: 16) {
            InfoTile(number: "1", title: "Add", value: "Open, paste, capture, or drop source files.", stepCircleSize: stepCircleSize)
            InfoTile(number: "2", title: "Process", value: "Watch page thumbnails and OCR progress.", stepCircleSize: stepCircleSize)
            InfoTile(number: "3", title: "Review", value: "Fix OCR text, check page order, and inspect notes.", stepCircleSize: stepCircleSize)
            InfoTile(number: "4", title: "Export", value: "Save Markdown, TXT, HTML, PDF, CSV, or JSON.", stepCircleSize: stepCircleSize)
        }
    }

    private func announceDropResult(count: Int) {
        guard count > 0 else { return }
        let announcement = "Imported \(count) file\(count == 1 ? "" : "s")"
        let target: Any = NSApp.mainWindow ?? NSApp.mainMenu?.items.first?.view ?? NSApp
        NSAccessibility.post(
            element: target,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}

private struct InfoTile: View {
    let number: String
    let title: String
    let value: String
    let stepCircleSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AccessibleStyle.accentGradient)
                Text(number)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: stepCircleSize, height: stepCircleSize)
            .shadow(color: AccessibleStyle.accent.opacity(0.4), radius: 5, y: 2)

            Text(title)
                .font(.headline)
                .foregroundStyle(AccessibleStyle.primaryText)

            Text(value)
                .font(.callout)
                .foregroundStyle(AccessibleStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .accessiblePanel()
    }
}
