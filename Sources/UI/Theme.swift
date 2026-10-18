import SwiftUI
import AppKit

enum Theme {
    // MARK: Couleurs de gravité

    static func color(_ s: Severity) -> Color {
        switch s {
        case .normal:   return .accentColor
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    static func nsColor(_ s: Severity) -> NSColor {
        switch s {
        case .normal:   return .controlAccentColor
        case .warning:  return .systemOrange
        case .critical: return .systemRed
        }
    }

    static func label(_ s: Severity) -> String {
        switch s {
        case .normal:   return "Espace confortable"
        case .warning:  return "Espace à surveiller"
        case .critical: return "Espace critique"
        }
    }

    /// La barre de menus suit le réglage système. On le lit directement :
    /// l'appearance effective d'une app accessoire n'est pas fiable.
    static var menuBarIsDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    // MARK: Métriques

    static let panelWidth: CGFloat = 340
    static let corner: CGFloat = 10
    static let rowHeight: CGFloat = 26
}

/// Dégradé discret réutilisé sous les courbes.
extension ShapeStyle where Self == LinearGradient {
    static func areaFill(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.28), color.opacity(0.02)],
            startPoint: .top, endPoint: .bottom)
    }
}
