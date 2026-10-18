import AppKit

/// Rendu de l'élément de barre de menus.
///
/// Deux contraintes dictent ce fichier. D'une part `contentTintColor` est ignoré
/// sur un NSStatusBarButton et le rendu « template » se résout en noir : les
/// images sont donc teintées à la main. D'autre part une barre de menus chargée
/// n'affiche pas un élément trop large — macOS lui attribue une position mais ne
/// le dessine pas. D'où la jauge annulaire de 18 pt proposée par défaut.
enum StatusIcon {

    static func image(style: MenuBarStyle, ratio: Double, severity: Severity) -> NSImage? {
        switch style {
        case .ring:
            return ring(ratio: ratio, severity: severity)
        case .icon, .compact, .full:
            let symbol: String
            switch severity {
            case .critical: symbol = "exclamationmark.triangle.fill"
            case .warning:  symbol = "internaldrive.fill"
            case .normal:   symbol = "internaldrive"
            }
            return tinted(symbol, color: tint(severity))
        }
    }

    static func title(style: MenuBarStyle, free: Int64) -> String {
        switch style {
        case .ring, .icon: return ""
        case .compact:     return " " + String(Int(Fmt.go(free).rounded()))
        case .full:        return " " + Fmt.size(free)
        }
    }

    private static func tint(_ s: Severity) -> NSColor {
        switch s {
        case .normal:   return Theme.menuBarIsDark ? .white : .black
        case .warning:  return .systemOrange
        case .critical: return .systemRed
        }
    }

    // MARK: Jauge annulaire

    private static func ring(ratio: Double, severity: Severity) -> NSImage {
        let side: CGFloat = 18
        let line: CGFloat = 2.6
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        let center = NSPoint(x: side / 2, y: side / 2)
        let radius = (side - line) / 2 - 0.5
        let base = tint(severity)

        // Piste
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = line
        base.withAlphaComponent(severity == .normal ? 0.25 : 0.22).setStroke()
        track.stroke()

        // Remplissage, horaire depuis midi
        let clamped = min(max(ratio, 0), 1)
        if clamped > 0.001 {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius,
                          startAngle: 90, endAngle: 90 - 360 * clamped, clockwise: true)
            arc.lineWidth = line
            arc.lineCapStyle = .round
            base.setStroke()
            arc.stroke()
        }

        image.isTemplate = false
        return image
    }

    // MARK: Symbole SF teinté

    private static func tinted(_ name: String, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: "Espace disque")
        else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let symbol = base.withSymbolConfiguration(config) ?? base
        let size = symbol.size
        let out = NSImage(size: size)
        out.lockFocus()
        symbol.draw(in: NSRect(origin: .zero, size: size))
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }
}
