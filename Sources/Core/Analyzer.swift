import Foundation

struct Trend {
    var free: Int64 = 0
    var total: Int64 = 0
    var delta1h: Int64?
    var delta24h: Int64?
    var delta7d: Int64?
    var ratePerHour: Double?

    var used: Int64 { total - free }
    var usedRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }

    /// Projection naïve : à ce rythme, combien de temps avant saturation ?
    var timeToFull: TimeInterval? {
        guard let rate = ratePerHour, rate < -100_000_000 else { return nil }
        let seconds = Double(free) / -rate * 3600
        // Au-dela d'un an, extrapoler trois heures de mesures n'apprend rien.
        return seconds < 365 * 86400 ? seconds : nil
    }
}

enum Analyzer {
    /// Échantillon le plus proche d'un instant passé, avec une tolérance
    /// proportionnelle : inutile de comparer à « il y a 24 h » un relevé vieux de 3 jours.
    static func sample(_ history: [Sample], ago: TimeInterval) -> Sample? {
        let target = Date().timeIntervalSince1970 - ago
        let tolerance = max(900, ago * 0.25)
        return history
            .filter { abs($0.t - target) <= tolerance }
            .min { abs($0.t - target) < abs($1.t - target) }
    }

    static func trend(_ history: [Sample]) -> Trend {
        var t = Trend()
        guard let last = history.last else { return t }
        t.free = last.free
        t.total = last.total
        if let s = sample(history, ago: 3600)   { t.delta1h  = last.free - s.free }
        if let s = sample(history, ago: 86400)  { t.delta24h = last.free - s.free }
        if let s = sample(history, ago: 604800) { t.delta7d  = last.free - s.free }

        // Pente sur les 3 dernières heures : assez long pour lisser le bruit,
        // assez court pour réagir à un build qui s'emballe.
        let cutoff = Date().timeIntervalSince1970 - 3 * 3600
        let recent = history.filter { $0.t >= cutoff }
        if recent.count >= 3, let first = recent.first, let final = recent.last {
            let hours = (final.t - first.t) / 3600
            if hours > 0.2 { t.ratePerHour = Double(final.free - first.free) / hours }
        }
        return t
    }

    static func rows(_ folders: FolderStore) -> [FolderRow] {
        guard let current = folders.current else { return [] }
        let previous = folders.previous
        let rows = current.sizes.map { kv in
            FolderRow(path: kv.key, size: kv.value,
                      delta: previous?.sizes[kv.key].map { kv.value - $0 })
        }
        // Une variation sous le seuil de bruit ne doit pas départager deux
        // dossiers : sans cela le classement paraît aléatoire quand rien ne bouge.
        func key(_ r: FolderRow) -> Int64 {
            guard let d = r.delta, d >= Fmt.noiseFloor else { return 0 }
            return d
        }
        return rows.sorted { a, b in
            let ka = key(a), kb = key(b)
            return ka == kb ? a.size > b.size : ka > kb
        }
    }
}
