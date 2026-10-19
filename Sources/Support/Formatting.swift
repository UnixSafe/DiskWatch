import Foundation

enum Fmt {
    static let locale = Locale(identifier: "fr_FR")

    private static func number(_ decimals: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = locale
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f
    }

    static func go(_ bytes: Int64) -> Double { Double(bytes) / 1_000_000_000 }

    /// Taille lisible, avec le nombre de décimales adapté à l'ordre de grandeur.
    static func size(_ bytes: Int64, decimals: Int? = nil) -> String {
        let value = go(bytes)
        let d = decimals ?? (value < 10 ? 1 : 0)
        return (number(d).string(from: NSNumber(value: value)) ?? "—") + " Go"
    }

    static func delta(_ bytes: Int64) -> String {
        (bytes >= 0 ? "+" : "−") + size(abs(bytes), decimals: abs(bytes) < 10_000_000_000 ? 1 : 0)
    }

    /// En deça de 50 Mo la variation relève du bruit de fond : un tiret est
    /// plus honnête qu'un « +0,0 Go » qui laisse croire à une mesure fine.
    static let noiseFloor: Int64 = 50_000_000

    static func deltaOrDash(_ bytes: Int64?) -> String {
        guard let bytes, abs(bytes) >= noiseFloor else { return "—" }
        return delta(bytes)
    }

    static func rate(_ bytesPerHour: Double) -> String {
        let v = bytesPerHour / 1_000_000_000
        return (v >= 0 ? "+" : "−") + (number(1).string(from: NSNumber(value: abs(v))) ?? "—") + " Go/h"
    }

    static func percent(_ ratio: Double) -> String {
        (number(0).string(from: NSNumber(value: ratio * 100)) ?? "—") + " %"
    }

    static func age(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 90 { return "à l'instant" }
        if s < 3600 { return "il y a \(Int(s / 60)) min" }
        if s < 86400 {
            let h = Int(s / 3600)
            return "il y a \(h) h"
        }
        let d = Int(s / 86400)
        return d == 1 ? "hier" : "il y a \(d) jours"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds)) s" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        if seconds < 48 * 3600 { return "\(Int(seconds / 3600)) h" }
        let days = Int(seconds / 86400)
        if days < 60 { return "\(days) j" }
        let months = Int((seconds / 86400 / 30.44).rounded())
        return months < 12 ? "\(months) mois" : "plus d'un an"
    }
}

enum Paths {
    static var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    static func expand(_ p: String) -> String { (p as NSString).expandingTildeInPath }

    static func abbreviate(_ p: String) -> String {
        p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    /// Nom court pour l'affichage : les deux derniers segments suffisent à situer un dossier.
    static func display(_ p: String) -> String {
        let parts = abbreviate(expand(p)).split(separator: "/")
        guard parts.count > 2 else { return abbreviate(expand(p)) }
        return parts.suffix(2).joined(separator: "/")
    }
}
