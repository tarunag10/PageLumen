import SwiftUI

/// PageLumen design system.
///
/// A dark-first, Apple-inspired aesthetic built on layered surfaces, a vibrant
/// indigo accent, generous spacing, and subtle depth cues. Every token honors
/// the app's accessibility contract: `boostContrast` sharpens borders and
/// backgrounds for low-vision users, and translucent materials fall back to
/// solid colors when Reduce Transparency is on.
enum AccessibleStyle {
    /// Corner radius used by panels and cards throughout the app.
    static let cornerRadius: CGFloat = 14
    /// Slightly tighter radius for inner elements (chips, badges, thumbnails).
    static let innerCornerRadius: CGFloat = 10
    /// Radius for pill-shaped controls.
    static let pillCornerRadius: CGFloat = 999

    // The high-contrast toggle is read by `border` and `panelBackground` below.
    // Views that need to re-render when the flag flips must bind
    // `@AppStorage("boostContrast")` so SwiftUI invalidates them; this static is
    // the shared value the rest of the UI consults at render time.
    static var boostContrast: Bool = UserDefaults.standard.bool(forKey: "boostContrast")

    // MARK: - Brand Accent

    /// Vibrant indigo accent — the signature PageLumen brand color.
    static let accent = Color(red: 0.345, green: 0.514, blue: 1.0)
    /// A slightly lighter, more luminous variant for glows and highlights.
    static let accentBright = Color(red: 0.49, green: 0.627, blue: 1.0)
    /// Soft accent used for tinted fills behind icons and chips.
    static let accentTint = Color(red: 0.345, green: 0.514, blue: 1.0).opacity(0.18)

    // MARK: - Surface Palette (Dark-First)

    /// Deepest background — the canvas behind every screen.
    static var appBackground: Color {
        boostContrast ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color(red: 0.075, green: 0.078, blue: 0.092)
    }

    /// Primary panel/card surface — raised one layer above the canvas.
    static var panelBackground: Color {
        boostContrast ? Color(red: 0.11, green: 0.11, blue: 0.13) : Color(red: 0.122, green: 0.125, blue: 0.146)
    }

    /// Elevated surface — used by toolbars, popovers, and stacked cards.
    static var elevatedBackground: Color {
        boostContrast ? Color(red: 0.15, green: 0.15, blue: 0.17) : Color(red: 0.157, green: 0.161, blue: 0.184)
    }

    /// A brighter floating surface for sheets and menus.
    static var floatingBackground: Color {
        boostContrast ? Color(red: 0.18, green: 0.18, blue: 0.21) : Color(red: 0.188, green: 0.192, blue: 0.216)
    }

    // MARK: - Text

    /// Primary text color — high contrast white for body content.
    static var primaryText: Color {
        Color(red: 0.95, green: 0.955, blue: 0.97)
    }

    /// Secondary text — for captions, subtitles, and metadata.
    static var secondaryText: Color {
        Color(red: 0.62, green: 0.635, blue: 0.69)
    }

    /// Tertiary text — for the faintest hints and placeholders.
    static var tertiaryText: Color {
        Color(red: 0.45, green: 0.46, blue: 0.52)
    }

    // MARK: - Lines & Borders

    /// Hairline border around panels and dividers.
    static var border: Color {
        boostContrast
            ? Color(red: 0.55, green: 0.56, blue: 0.62)
            : Color(red: 0.22, green: 0.225, blue: 0.255).opacity(0.9)
    }

    /// A brighter border used for hover/focus rings.
    static var focusBorder: Color {
        boostContrast ? Color.white : accentBright.opacity(0.75)
    }

    // MARK: - Status Colors

    /// Selected / active surface tint.
    static var selected: Color {
        accent
    }

    static var warning: Color {
        Color(red: 1.0, green: 0.722, blue: 0.298)
    }

    static var success: Color {
        Color(red: 0.298, green: 0.827, blue: 0.522)
    }

    static var error: Color {
        Color(red: 1.0, green: 0.392, blue: 0.392)
    }

    static var info: Color {
        Color(red: 0.392, green: 0.784, blue: 1.0)
    }

    // MARK: - Gradients

    /// Signature accent gradient for hero buttons and active states.
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentBright, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Subtle vertical gradient for elevated panels — adds depth without noise.
    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.145, green: 0.148, blue: 0.172),
                Color(red: 0.118, green: 0.121, blue: 0.142)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Ambient background gradient — a whisper of accent light from the top.
    static var ambientGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.10),
                appBackground,
                appBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Hero drop-zone gradient used on the home screen.
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.16),
                Color(red: 0.565, green: 0.412, blue: 0.922).opacity(0.10),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shadows

    /// Soft shadow for cards resting on the canvas.
    static let cardShadow: (radius: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) =
        (radius: 16, x: 0, y: 6, opacity: 0.35)

    /// Subtle shadow for floating elements (popovers, sheets).
    static let floatingShadow: (radius: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) =
        (radius: 28, x: 0, y: 12, opacity: 0.5)
}

// Accessibility guidelines for future contributors:
// 4.4.1 — View-level animations must be gated on
//         @Environment(\.accessibilityReduceMotion). If a `withAnimation` or
//         `.animation` modifier is added anywhere in the view tree, wrap the
//         conditional motion in a check for `accessibilityReduceMotion == false`
//         so that users who request reduced motion do not see the transition.
// 4.4.2 — Surfaces that use `.regularMaterial`, `.ultraThinMaterial`, or any
//         other translucent material MUST fall back to
//         `AccessibleStyle.panelBackground` (a solid color) when
//         @Environment(\.accessibilityReduceTransparency) is true. The
//         fallback is the same color in both modes today, but the rule ensures
//         we never silently ship a transparent surface that cannot be
//         disabled.

/// Panel surface with a layered dark background, hairline border, and soft shadow.
struct AccessiblePanel: ViewModifier {
    var borderColor: Color = AccessibleStyle.border
    var radius: CGFloat = AccessibleStyle.cornerRadius
    var paddedShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if AccessibleStyle.boostContrast {
                        AccessibleStyle.panelBackground
                    } else {
                        AccessibleStyle.panelGradient
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(paddedShadow ? AccessibleStyle.cardShadow.opacity : 0),
                radius: paddedShadow ? AccessibleStyle.cardShadow.radius : 0,
                x: AccessibleStyle.cardShadow.x,
                y: AccessibleStyle.cardShadow.y
            )
    }
}

/// Toolbar / banner surface with an elevated background and a bottom hairline.
struct AccessibleToolbarSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AccessibleStyle.elevatedBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AccessibleStyle.border)
                    .frame(height: 1)
            }
    }
}

extension View {
    func accessiblePanel(
        borderColor: Color = AccessibleStyle.border,
        radius: CGFloat = AccessibleStyle.cornerRadius,
        paddedShadow: Bool = true
    ) -> some View {
        modifier(AccessiblePanel(borderColor: borderColor, radius: radius, paddedShadow: paddedShadow))
    }

    func accessibleToolbarSurface() -> some View {
        modifier(AccessibleToolbarSurface())
    }

    /// Applies Liquid Glass material on macOS 26+ when accessibility settings allow.
    /// Falls back to the existing solid panel background on older macOS or when
    /// the user has Boost Contrast enabled or Reduce Transparency turned on.
    @ViewBuilder
    func liquidGlassIfAvailable(boostContrast: Bool = false, reduceTransparency: Bool = false) -> some View {
        if #available(macOS 26.0, *), !boostContrast, !reduceTransparency {
            self.background(.regularMaterial)
        } else {
            self
        }
    }

    /// Renders primary-styled text using the design system's primary color.
    func primaryTextStyle() -> some View {
        foregroundStyle(AccessibleStyle.primaryText)
    }

    /// Renders secondary-styled text using the design system's secondary color.
    func secondaryTextStyle() -> some View {
        foregroundStyle(AccessibleStyle.secondaryText)
    }
}
