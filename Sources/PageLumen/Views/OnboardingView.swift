import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    // Re-render when the high-contrast toggle changes so the onboarding card
    // surfaces pick up the new border / background colors.
    @AppStorage("boostContrast") private var boostContrast = false
    @ScaledMetric(relativeTo: .title) private var cardIconSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AccessibleStyle.accent.opacity(0.16))
                        .frame(width: 92, height: 92)
                        .blur(radius: 6)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(AccessibleStyle.accentGradient)
                }

                Text("Welcome to PageLumen")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AccessibleStyle.primaryText)
                    .multilineTextAlignment(.center)

                Text("Turn any PDF, image, scan, or slide into a clean, readable, accessible document — all on your Mac.")
                    .font(.title3)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            VStack(spacing: 14) {
                OnboardingCard(
                    icon: "lock.shield",
                    title: "Privacy first",
                    message: "Documents stay on this Mac. There is no cloud upload, no telemetry, and no third-party SDK.",
                    tint: AccessibleStyle.success
                )
                OnboardingCard(
                    icon: "rectangle.stack.badge.person.crop",
                    title: "Four-step workflow",
                    message: "Add a document, let PageLumen extract and order the text, review anything that needs a second look, then export to Markdown, HTML, PDF, DOCX, or audio.",
                    tint: AccessibleStyle.accentBright
                )
                OnboardingCard(
                    icon: "accessibility",
                    title: "Built for accessibility",
                    message: "High-contrast mode, VoiceOver labels, scalable type, and an in-app speech engine are on by default.",
                    tint: AccessibleStyle.info
                )
            }

            Button {
                hasSeenOnboarding = true
                isPresented = false
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
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
        .padding(36)
        .frame(width: 540)
        .background(AccessibleStyle.appBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                .stroke(AccessibleStyle.border, lineWidth: 1)
        }
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
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: cardIconSize, weight: .regular))
                    .foregroundStyle(tint)
            }
            .frame(width: 52, height: 52)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AccessibleStyle.primaryText)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AccessibleStyle.panelBackground, in: RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                .stroke(AccessibleStyle.border)
        }
        .accessibilityElement(children: .combine)
    }
}
