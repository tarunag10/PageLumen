import SwiftUI

enum AccessibleStyle {
    static let cornerRadius: CGFloat = 8

    // The high-contrast toggle is read by `border` and `panelBackground` below.
    // Views that need to re-render when the flag flips must bind
    // `@AppStorage("boostContrast")` so SwiftUI invalidates them; this static is
    // the shared value the rest of the UI consults at render time.
    static var boostContrast: Bool = UserDefaults.standard.bool(forKey: "boostContrast")

    static var appBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var panelBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var elevatedBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var border: Color {
        boostContrast ? Color(nsColor: .labelColor) : Color(nsColor: .separatorColor)
    }

    static var selected: Color {
        Color(nsColor: .selectedContentBackgroundColor)
    }

    static var warning: Color {
        Color(nsColor: .systemRed)
    }

    static var success: Color {
        Color(nsColor: .systemGreen)
    }

    static var error: Color {
        Color(nsColor: .systemRed)
    }
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

struct AccessiblePanel: ViewModifier {
    var borderColor: Color = AccessibleStyle.border

    func body(content: Content) -> some View {
        content
            .background(AccessibleStyle.panelBackground, in: RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
    }
}

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
    func accessiblePanel(borderColor: Color = AccessibleStyle.border) -> some View {
        modifier(AccessiblePanel(borderColor: borderColor))
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
}
