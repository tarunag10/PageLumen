import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    // Re-render when the high-contrast toggle changes so the onboarding card
    // surfaces pick up the new border / background colors.
    @AppStorage("boostContrast") private var boostContrast = false
    @ScaledMetric(relativeTo: .title) private var cardIconSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Welcome to PageLumen")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Turn any PDF, image, scan, or slide into a clean, readable, accessible document — all on your Mac.")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            VStack(spacing: 16) {
                OnboardingCard(
                    icon: "lock.shield",
                    title: "Privacy first",
                    message: "Documents stay on this Mac. There is no cloud upload, no telemetry, and no third-party SDK.",
                    tint: .green
                )
                OnboardingCard(
                    icon: "rectangle.stack.badge.person.crop",
                    title: "Four-step workflow",
                    message: "Add a document, let PageLumen extract and order the text, review anything that needs a second look, then export to Markdown, HTML, PDF, DOCX, or audio.",
                    tint: .accentColor
                )
                OnboardingCard(
                    icon: "accessibility",
                    title: "Built for accessibility",
                    message: "High-contrast mode, VoiceOver labels, scalable type, and an in-app speech engine are on by default.",
                    tint: .blue
                )
            }

            Button {
                hasSeenOnboarding = true
                isPresented = false
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .accessibilityHint("Closes the welcome screen and opens the main workspace.")

            Button("Show this on launch") {
                // The "Show on launch" preference lives in Settings, so dismissing
                // the welcome screen here just closes the sheet for this session.
                isPresented = false
            }
            .buttonStyle(.link)
            .accessibilityHint("Dismiss the welcome screen now. You can reopen it from Settings.")
        }
        .padding(32)
        .frame(width: 520)
        .background(AccessibleStyle.appBackground)
    }
}

private struct OnboardingCard: View {
    @AppStorage("boostContrast") private var boostContrast = false
    @ScaledMetric(relativeTo: .title) private var cardIconSize: CGFloat = 36

    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: cardIconSize, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AccessibleStyle.panelBackground, in: RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                .stroke(AccessibleStyle.border)
        }
        .accessibilityElement(children: .combine)
    }
}
