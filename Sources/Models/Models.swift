import Foundation

/// Un relevé ponctuel de l'espace disque.
struct Sample: Codable, Identifiable {
    let t: Double
    let free: Int64
    let total: Int64

    var id: Double { t }
    var date: Date { Date(timeIntervalSince1970: t) }
    var used: Int64 { total - free }
    var usedRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

/// Une mesure complète des dossiers surveillés.
struct Snapshot: Codable {
    var t: Double
    var sizes: [String: Int64]
    var date: Date { Date(timeIntervalSince1970: t) }
}

struct FolderStore: Codable {
    var current: Snapshot?
    var previous: Snapshot?
}

/// Une ligne prête à afficher : taille actuelle et variation depuis la mesure précédente.
struct FolderRow: Identifiable {
    let path: String
    let size: Int64
    let delta: Int64?
    var id: String { path }
    var display: String { Paths.display(path) }
    var full: String { Paths.abbreviate(Paths.expand(path)) }
}

/// Mémoire anti-spam : sans elle, une alerte se répéterait à chaque relevé.
struct AlertState: Codable {
    var lastLevelGo: Double?
    var lastSpikeAt: Double?
    var lastDailyAt: Double?
    var folderNotifiedAt: [String: Double] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastLevelGo      = try c.decodeIfPresent(Double.self, forKey: .lastLevelGo)
        lastSpikeAt      = try c.decodeIfPresent(Double.self, forKey: .lastSpikeAt)
        lastDailyAt      = try c.decodeIfPresent(Double.self, forKey: .lastDailyAt)
        folderNotifiedAt = try c.decodeIfPresent([String: Double].self, forKey: .folderNotifiedAt) ?? [:]
    }
}

enum MenuBarStyle: String, Codable, CaseIterable, Identifiable {
    case ring, icon, compact, full
    var id: String { rawValue }

    var label: String {
        switch self {
        case .ring:    return "Jauge"
        case .icon:    return "Icône"
        case .compact: return "Icône + nombre"
        case .full:    return "Icône + taille"
        }
    }

    /// Largeurs relevées sur l'élément de barre réel, arrondis compris.
    var hint: String {
        switch self {
        case .ring:    return "Anneau de remplissage, 36 pt — le taux d'occupation d'un coup d'œil"
        case .icon:    return "Disque seul, 36 pt — change de couleur selon la gravité"
        case .compact: return "« 117 », 61 pt — demande un peu de place"
        case .full:    return "« 117 Go », 92 pt — demande une barre dégagée"
        }
    }
}

/// Réglages persistés. Le décodage tolère les clés absentes : un fichier écrit
/// par une version antérieure reste lisible après une mise à jour.
struct Config: Codable, Equatable {
    var sampleIntervalMinutes: Int = 5
    var scanIntervalHours: Int = 6
    var lowSpaceThresholdsGo: [Double] = [60, 30, 15, 7]
    var spikeGoPerHour: Double = 5
    var dailyDropGo: Double = 25
    var folderGrowthGo: Double = 5
    var historyRetentionDays: Int = 60
    var menuBarStyle: MenuBarStyle = .ring
    var notificationsEnabled: Bool = true
    var watchedPaths: [String] = Config.defaultPaths

    static let defaultPaths = [
        "~/Documents", "~/Downloads", "~/Library/Caches", "~/Library/Containers",
        "~/.cache", "~/.codex", "~/.claude", "~/.gemini",
    ]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        sampleIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .sampleIntervalMinutes) ?? d.sampleIntervalMinutes
        scanIntervalHours     = try c.decodeIfPresent(Int.self, forKey: .scanIntervalHours) ?? d.scanIntervalHours
        lowSpaceThresholdsGo  = try c.decodeIfPresent([Double].self, forKey: .lowSpaceThresholdsGo) ?? d.lowSpaceThresholdsGo
        spikeGoPerHour        = try c.decodeIfPresent(Double.self, forKey: .spikeGoPerHour) ?? d.spikeGoPerHour
        dailyDropGo           = try c.decodeIfPresent(Double.self, forKey: .dailyDropGo) ?? d.dailyDropGo
        folderGrowthGo        = try c.decodeIfPresent(Double.self, forKey: .folderGrowthGo) ?? d.folderGrowthGo
        historyRetentionDays  = try c.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? d.historyRetentionDays
        menuBarStyle          = try c.decodeIfPresent(MenuBarStyle.self, forKey: .menuBarStyle) ?? d.menuBarStyle
        notificationsEnabled  = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        watchedPaths          = try c.decodeIfPresent([String].self, forKey: .watchedPaths) ?? d.watchedPaths
    }

    /// Seuils triés du plus permissif au plus sévère, doublons écartés.
    var sortedThresholds: [Double] {
        Array(Set(lowSpaceThresholdsGo)).sorted(by: >)
    }
}

/// Niveau de gravité dérivé de l'espace restant.
enum Severity {
    case normal, warning, critical

    static func of(freeGo: Double, thresholds: [Double]) -> Severity {
        let sorted = thresholds.sorted(by: >)
        guard let first = sorted.first else { return .normal }
        let severe = sorted.count >= 2 ? sorted[1] : first
        if freeGo < severe { return .critical }
        if freeGo < first { return .warning }
        return .normal
    }
}
