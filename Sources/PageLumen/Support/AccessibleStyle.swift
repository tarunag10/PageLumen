import SwiftUI

enum AccessibleStyle {
    static let cornerRadius: CGFloat = 8

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
        Color(nsColor: .separatorColor)
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
}
