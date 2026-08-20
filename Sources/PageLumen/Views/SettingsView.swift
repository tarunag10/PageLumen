import AVFoundation
import PageLumenCore
import SwiftUI
import TipKit

struct SettingsView: View {
    /// Non-nil only for the isolated UI-test launch route. Normal Settings
    /// uses the persisted preference and remains fully user-editable.
    let appearanceOverride: String?

    init(appearanceOverride: String? = nil) {
        self.appearanceOverride = appearanceOverride
    }

    @Environment(DocumentStore.self) private var store
    @AppStorage("privacyMode") private var privacyMode = true
    @AppStorage("ocrProfile") private var ocrProfile = "General"
    @AppStorage("languageHint") private var languageHint = "Automatic"
    @AppStorage("boostContrast") private var boostContrast = false
    @AppStorage("appearancePreference") private var appearancePreference = "system"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("intelligenceMode") private var intelligenceModeRaw = IntelligenceMode.off.rawValue
    @AppStorage(DocumentRepositorySettings.keepSearchableLocalCopiesKey) private var keepSearchableLocalCopies = false
    @State private var isShowingForgetConfirmation = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("PageLumen Preferences", systemImage: "slider.horizontal.3")
                        .font(.title2.weight(.semibold))
                    Text("Tune recognition, export defaults, and release-readiness checks for the current native workflow.")
                        .foregroundStyle(AccessibleStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section("Privacy") {
                Toggle("Privacy mode", isOn: $privacyMode)
                    .accessibilityIdentifier("settings.privacyMode")
                    .onChange(of: privacyMode) { _, enabled in
                        store.statusMessage = enabled ? "Privacy mode enabled; translated export is disabled" : "Privacy mode disabled"
                    }
                Text("Privacy mode keeps imports local and disables translation export, which may use a network-assisted service.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Section("Library") {
                Toggle("Keep searchable local copies", isOn: $keepSearchableLocalCopies)
                    .accessibilityIdentifier("settings.searchableCopies")
                    .onChange(of: keepSearchableLocalCopies) { _, enabled in
                        store.setKeepSearchableLocalCopies(enabled)
                    }
                Text("Off by default. When enabled, PageLumen may search retained OCR text on this Mac. Turning it off stops library search without deleting existing recent documents or source files.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)

                Button(role: .destructive) {
                    isShowingForgetConfirmation = true
                } label: {
                    Label("Forget all recent documents", systemImage: "trash")
                }
                .accessibilityIdentifier("settings.forgetAll")
                .disabled(store.recentDocuments.isEmpty)
                .confirmationDialog(
                    "Forget all recent documents? This cannot be undone.",
                    isPresented: $isShowingForgetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Forget all", role: .destructive) {
                        store.forgetAllRecentDocuments()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("PageLumen will clear \(store.recentDocuments.count) document\(store.recentDocuments.count == 1 ? "" : "s") from this Mac's local library. Imported files on disk are not deleted.")
                }
                Text("Recent documents are stored only in this Mac's memory. Use Forget all to clear them when sharing the device.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                LabeledContent("Library storage", value: store.libraryStorageSizeLabel)
                    .accessibilityHint("Size of PageLumen's local recent-document store. Source files are not included.")
                LabeledContent("Last cleared", value: store.lastLibraryClearLabel)
                    .accessibilityHint("The last time PageLumen cleared its retained local library copies")
                Label(store.persistenceStatus.label, systemImage: store.persistenceStatus.systemImage)
                    .font(.callout)
                    .foregroundStyle(store.persistenceStatus == .available ? AccessibleStyle.success : AccessibleStyle.warning)
                    .accessibilityHint("The active document remains usable if local recent-document storage is degraded.")
            }

            Section("Display") {
                Picker("Appearance", selection: $appearancePreference) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .accessibilityIdentifier("settings.appearance")
                .accessibilityHint("Choose System to follow macOS appearance and accessibility settings")
                Text("Current preview: \(appearanceLabel(appearanceOverride ?? appearancePreference)) appearance")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .accessibilityIdentifier("settings.appearanceValue")
                Toggle("Boost contrast", isOn: $boostContrast)
                    .accessibilityIdentifier("settings.boostContrast")
                    .onChange(of: boostContrast) { _, newValue in
                        AccessibleStyle.boostContrast = newValue
                    }
                Text("System follows macOS appearance. Boost contrast sharpens borders and panel contrast for low-vision users.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }
            .popoverTip(BoostContrastTip(), arrowEdge: .top)

            Section("Watch folder") {
                Toggle("Monitor a selected folder", isOn: Binding(
                    get: { store.watchFolderEnabled },
                    set: { store.setWatchFolderEnabled($0) }
                ))
                Button {
                    store.chooseWatchFolder()
                } label: {
                    Label("Choose folder…", systemImage: "folder.badge.plus")
                }
                Text(store.watchFolderPathLabel)
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                Text("New supported files are reported here but never imported automatically. Confirm each file before processing.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)

                if !store.watchFolderCandidates.isEmpty {
                    ForEach(store.watchFolderCandidates) { candidate in
                        HStack {
                            Label(candidate.url.lastPathComponent, systemImage: "doc")
                                .lineLimit(1)
                            Spacer()
                            Button("Import") {
                                store.importWatchFolderCandidate(candidate)
                            }
                            Button("Ignore") {
                                store.dismissWatchFolderCandidate(candidate)
                            }
                            .buttonStyle(.borderless)
                        }
                        .accessibilityElement(children: .contain)
                    }
                }

                if !store.watchFolderFailures.isEmpty {
                    Text("Needs attention")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(store.watchFolderFailures) { failure in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(failure.fileName, systemImage: "exclamationmark.triangle")
                                .lineLimit(1)
                            Text(failure.message)
                                .font(.caption)
                                .foregroundStyle(AccessibleStyle.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button("Retry") {
                                    store.retryWatchFolderFailure(failure)
                                }
                                Button("Dismiss") {
                                    store.dismissWatchFolderFailure(failure)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Onboarding") {
                Toggle("Show welcome screen on launch", isOn: showOnLaunchBinding)
                Button {
                    NotificationCenter.default.post(name: .pageLumenShowOnboardingRequest, object: nil)
                } label: {
                    Label("Show welcome screen now", systemImage: "hand.wave")
                }
                Text("Uncheck \"Show welcome screen on launch\" to see the introduction again the next time you open PageLumen.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Section("Recognition") {
                Picker("OCR profile", selection: $ocrProfile) {
                    ForEach(OCRProfile.allCases) { profile in
                        Text(profile.rawValue).tag(profile.rawValue)
                    }
                }
                .onChange(of: ocrProfile) { _, newValue in
                    store.statusMessage = "Recognition profile set to \(newValue)"
                }

                Picker("Language hint", selection: $languageHint) {
                    Text("Automatic").tag("Automatic")
                    Text("English").tag("English")
                    Text("Hindi").tag("Hindi")
                    Text("Spanish").tag("Spanish")
                    Text("French").tag("French")
                }
                .onChange(of: languageHint) { _, _ in
                    store.applyLanguagePreference()
                    store.statusMessage = languageHint == "Automatic" ? "Language detection set to automatic" : "Language hint set to \(languageHint)"
                }
            }

            Section("On-device AI") {
                Picker("Intelligence mode", selection: $intelligenceModeRaw) {
                    ForEach(IntelligenceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .onChange(of: intelligenceModeRaw) { _, raw in
                    if let mode = IntelligenceMode(rawValue: raw) {
                        store.setIntelligenceMode(mode)
                    }
                }
                .accessibilityIdentifier("settings.intelligenceMode")
                .accessibilityHint("Choose whether PageLumen may use Apple Intelligence for the current summary")

                Toggle(
                    "Do not use intelligence for this document",
                    isOn: Binding(
                        get: { store.isIntelligenceOptedOutForCurrentDocument },
                        set: { store.setIntelligenceOptOutForCurrentDocument($0) }
                    )
                )
                .disabled(store.intelligenceMode == .off)
                .accessibilityIdentifier("settings.documentIntelligenceOptOut")
                Text("Apple Intelligence is opt-in and receives only bounded selected document text. This document-level control overrides the global mode and is retained locally by document identifier.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                intelligenceAvailabilityView
                Text("Apple Intelligence is optional. It receives only the selected document text and must not be treated as a source of truth without checking the cited page.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }
            .onAppear {
                if UserDefaults.standard.object(forKey: "intelligenceMode") == nil {
                    intelligenceModeRaw = store.intelligenceMode.rawValue
                }
            }

            Section("Export Defaults") {
                Toggle("Include headings", isOn: exportBinding(\.includeHeadings))
                Toggle("Include tables", isOn: exportBinding(\.includeTables))
                Toggle("Include chart and figure explanations", isOn: exportBinding(\.includeFigures))
                Toggle("Include page references", isOn: exportBinding(\.includePageReferences))
                Toggle("Include confidence notes", isOn: exportBinding(\.includeConfidenceNotes))
                Toggle("Include repeated headers and footers", isOn: exportBinding(\.includeHeadersAndFooters))

                Text("These defaults are used by the export screen and saved for future sessions.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Section("Review Status") {
                HStack {
                    Label(store.extractionReadinessLabel, systemImage: store.reviewIssueCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    Spacer()
                    Text("\(store.document.pageCount) page\(store.document.pageCount == 1 ? "" : "s")")
                        .foregroundStyle(AccessibleStyle.secondaryText)
                }

                if store.reviewIssueCount > 0 {
                    Button {
                        store.jumpToFirstReviewIssue()
                    } label: {
                        Label("Jump to first review item", systemImage: "scope")
                    }
                }
            }

            Section("Review Preset") {
                Picker("Preset", selection: Binding(
                    get: { store.reviewPreset },
                    set: { store.setReviewPreset($0) }
                )) {
                    ForEach(ReviewPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                Text(store.reviewPreset.explanation)
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                Text("Presets change review thresholds and warnings only; they never alter extracted source text.")
                    .font(.caption)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Section("PRD Coverage") {
                Text("Implemented locally: PDF/image import, paste image, batch import, screenshot capture, OCR, reading order, outline, editing, header/footer filtering, summaries, speech playback, Markdown/TXT/HTML/PDF/CSV/JSON exports, and privacy/profile settings.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)

                Text("Longer-term roadmap: scanner/browser imports, trained layout models, full PDF/UA validation, advanced chart data extraction, audio-file export, EPUB/LMS/integration exports, and enterprise administration.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Section("Translation") {
                Picker("Target language", selection: translationLanguageBinding) {
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("Hindi").tag("hi")
                    Text("German").tag("de")
                    Text("Japanese").tag("ja")
                    Text("Chinese (Simplified)").tag("zh-Hans")
                }
                .disabled(!translationAvailable)

                if !translationAvailable {
                    Label("Requires macOS 15 or later", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                }

                Text("On-device translation, private and free. The selected language is used by the Translate and Export Markdown action.")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            Section("Speech") {
                Toggle("Use Personal Voice if available", isOn: usePersonalVoiceBinding)
                if !personalVoiceAvailable {
                    Label("Personal Voice is not enrolled on this Mac. Set it up in System Settings > Accessibility > Personal Voice.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                }
                Picker("Voice", selection: speechVoiceBinding) {
                    Text("Default").tag("default")
                    if personalVoiceAvailable {
                        Text("Personal Voice").tag("personal")
                    }
                    ForEach(AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "en") }, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 580)
    }

    private func exportBinding(_ keyPath: WritableKeyPath<ExportOptions, Bool>) -> Binding<Bool> {
        Binding {
            store.exportOptions[keyPath: keyPath]
        } set: { newValue in
            store.exportOptions[keyPath: keyPath] = newValue
            store.persistExportDefaults()
        }
    }

    private func appearanceLabel(_ value: String) -> String {
        switch value {
        case "light": return "Light"
        case "dark": return "Dark"
        default: return "System"
        }
    }

    @ViewBuilder
    private var intelligenceAvailabilityView: some View {
        let explainer = IntelligentExplainer()
        Group {
            switch explainer.availability {
            case .available:
                Label(explainer.availabilityInfo.title, systemImage: "checkmark.circle")
                    .foregroundStyle(AccessibleStyle.success)
            case .unavailable, .notSupported:
                Label(explainer.availabilityInfo.message, systemImage: "info.circle")
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }
        }
        .accessibilityIdentifier("settings.intelligenceAvailability")

        Text(explainer.availabilityInfo.deviceRequirement)
            .font(.caption)
            .foregroundStyle(AccessibleStyle.secondaryText)
        Text(explainer.availabilityInfo.privacyBoundary + " " + explainer.availabilityInfo.inputScope)
            .font(.caption)
            .foregroundStyle(AccessibleStyle.secondaryText)
    }

    private var showOnLaunchBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { newValue in hasSeenOnboarding = !newValue }
        )
    }

    private var translationLanguageBinding: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: "translationTargetLanguage") ?? "en" },
            set: { UserDefaults.standard.set($0, forKey: "translationTargetLanguage") }
        )
    }

    private var usePersonalVoiceBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "usePersonalVoice") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "usePersonalVoice") }
        )
    }

    private var speechVoiceBinding: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: "speechVoiceIdentifier") ?? "default" },
            set: { UserDefaults.standard.set($0, forKey: "speechVoiceIdentifier") }
        )
    }

    private var translationAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    private var personalVoiceAvailable: Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.voiceTraits.contains(.isPersonalVoice) }
    }
}
