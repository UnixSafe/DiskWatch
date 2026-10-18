import Foundation
import AppKit
import SwiftUI
import Combine

/// Source de vérité unique de l'interface. Tout passe par le thread principal :
/// seules les mesures `du` partent sur une file de travail.
@MainActor
final class AppState: ObservableObject {

    @Published private(set) var trend = Trend()
    @Published private(set) var history: [Sample] = []
    @Published private(set) var rows: [FolderRow] = []
    @Published private(set) var lastScan: Date?
    @Published private(set) var previousScan: Date?
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var notificationsWorking = true

    @Published var config = Config() {
        didSet { onConfigChange(from: oldValue) }
    }

    private let store = Store()
    private let notifier = Notifier()
    private var scanner = FolderScanner()
    private var state = AlertState()
    private var folders = FolderStore()

    private var sampleTimer: Timer?
    private var scanTimer: Timer?
    private var suppressPersist = false

    var severity: Severity {
        Severity.of(freeGo: Fmt.go(trend.free), thresholds: config.sortedThresholds)
    }

    // MARK: Démarrage

    func start() {
        suppressPersist = true
        config = store.loadConfig()
        suppressPersist = false

        state = store.loadState()
        history = store.pruneHistory(retentionDays: config.historyRetentionDays)
        folders = store.loadFolders()
        refreshRows()
        notifier.setup()

        takeSample()
        scheduleTimers()

        let stale = folders.current.map {
            Date().timeIntervalSince($0.date) > Double(config.scanIntervalHours) * 3600
        } ?? true
        if stale { scan() }
    }

    func shutdown() {
        sampleTimer?.invalidate()
        scanTimer?.invalidate()
        scanner.cancel()
    }

    private func onConfigChange(from old: Config) {
        guard !suppressPersist, config != old else { return }
        store.save(config)
        if config.sampleIntervalMinutes != old.sampleIntervalMinutes
            || config.scanIntervalHours != old.scanIntervalHours {
            scheduleTimers()
        }
        if config.watchedPaths != old.watchedPaths { scan() }
        objectWillChange.send()
    }

    private func scheduleTimers() {
        sampleTimer?.invalidate()
        scanTimer?.invalidate()

        let s = TimeInterval(max(1, config.sampleIntervalMinutes) * 60)
        sampleTimer = Timer.scheduledTimer(withTimeInterval: s, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.takeSample() }
        }
        sampleTimer?.tolerance = s * 0.2

        let h = TimeInterval(max(1, config.scanIntervalHours) * 3600)
        scanTimer = Timer.scheduledTimer(withTimeInterval: h, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
        scanTimer?.tolerance = 300
    }

    // MARK: Relevés

    func takeSample() {
        guard let sample = Disk.sample() else { return }
        history.append(sample)
        store.append(sample)
        trend = Analyzer.trend(history)
        evaluateSpaceAlerts()
    }

    /// Historique restreint à une fenêtre, pour le graphique.
    func window(hours: Double) -> [Sample] {
        let cutoff = Date().timeIntervalSince1970 - hours * 3600
        return history.filter { $0.t >= cutoff }
    }

    // MARK: Mesure des dossiers

    func scan() {
        guard !isScanning, !config.watchedPaths.isEmpty else { return }
        isScanning = true
        scanProgress = 0
        let paths = config.watchedPaths
        let scanner = self.scanner

        Task.detached(priority: .utility) {
            let sizes = scanner.scan(paths) { done, total in
                Task { @MainActor [weak self] in
                    self?.scanProgress = total > 0 ? Double(done) / Double(total) : 0
                }
            }
            await MainActor.run { [weak self] in
                self?.finishScan(sizes)
            }
        }
    }

    func cancelScan() {
        scanner.cancel()
        scanner = FolderScanner()
        isScanning = false
        scanProgress = 0
    }

    private func finishScan(_ sizes: [String: Int64]) {
        isScanning = false
        scanProgress = 0
        guard !sizes.isEmpty else { return }
        folders.previous = folders.current
        folders.current = Snapshot(t: Date().timeIntervalSince1970, sizes: sizes)
        store.save(folders)
        refreshRows()
        evaluateFolderAlerts()
    }

    private func refreshRows() {
        rows = Analyzer.rows(folders)
        lastScan = folders.current?.date
        previousScan = folders.previous?.date
    }

    // MARK: Alertes

    private func notify(_ title: String, _ body: String) {
        guard config.notificationsEnabled else { return }
        notifier.send(title: title, body: body)
    }

    private func evaluateSpaceAlerts() {
        let now = Date().timeIntervalSince1970
        let freeGo = Fmt.go(trend.free)
        let thresholds = config.sortedThresholds
        let breached = thresholds.filter { freeGo < $0 }.min()

        // Réarmement d'abord : l'espace est remonté nettement au-dessus du
        // dernier seuil notifié, on autorise une nouvelle alerte plus tard.
        if let last = state.lastLevelGo, freeGo > last * 1.08 {
            state.lastLevelGo = breached
        }

        if let b = breached, state.lastLevelGo == nil || b < state.lastLevelGo! {
            notify("Espace disque faible",
                   "Seuil de \(Int(b)) Go franchi — il reste \(Fmt.size(trend.free)).")
            state.lastLevelGo = b
        }

        if let d = trend.delta1h, Fmt.go(-d) >= config.spikeGoPerHour,
           now - (state.lastSpikeAt ?? 0) > 1800 {
            notify("Chute rapide d'espace disque",
                   "\(Fmt.delta(d)) en 1 h — il reste \(Fmt.size(trend.free)). Analyse des dossiers lancée.")
            state.lastSpikeAt = now
            scan()
        }

        if let d = trend.delta24h, Fmt.go(-d) >= config.dailyDropGo,
           now - (state.lastDailyAt ?? 0) > 86400 {
            notify("Espace disque en baisse continue",
                   "\(Fmt.delta(d)) sur 24 h — il reste \(Fmt.size(trend.free)).")
            state.lastDailyAt = now
        }

        store.save(state)
    }

    private func evaluateFolderAlerts() {
        guard let current = folders.current, let previous = folders.previous else { return }
        guard current.t - previous.t > 180 else { return }
        let now = Date().timeIntervalSince1970

        for row in rows {
            guard let delta = row.delta, Fmt.go(delta) >= config.folderGrowthGo else { continue }
            guard now - (state.folderNotifiedAt[row.path] ?? 0) > 21600 else { continue }
            notify("Dossier en forte croissance",
                   "\(row.full) : \(Fmt.delta(delta)) → \(Fmt.size(row.size))")
            state.folderNotifiedAt[row.path] = now
        }
        store.save(state)
    }

    // MARK: Actions de l'interface

    func copyReport() {
        var lines: [String] = []
        lines.append("DiskWatch — " + DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
        lines.append("Volume : \(Fmt.size(trend.free)) libres sur \(Fmt.size(trend.total)) (\(Fmt.percent(trend.usedRatio)) occupé)")
        if let d = trend.delta1h  { lines.append("Variation 1 h  : \(Fmt.delta(d))") }
        if let d = trend.delta24h { lines.append("Variation 24 h : \(Fmt.delta(d))") }
        if let d = trend.delta7d  { lines.append("Variation 7 j  : \(Fmt.delta(d))") }
        if let r = trend.ratePerHour { lines.append("Tendance 3 h   : \(Fmt.rate(r))") }
        if let t = trend.timeToFull  { lines.append("Saturation dans : \(Fmt.duration(t)) à ce rythme") }
        lines.append("Échantillons   : \(history.count)")

        if !rows.isEmpty, let scan = lastScan {
            lines.append("")
            lines.append("Dossiers surveillés (mesurés \(Fmt.age(scan))) :")
            for r in rows {
                let d = r.delta.map { "  (\(Fmt.delta($0)))" } ?? ""
                lines.append("  \(Fmt.size(r.size))\t\(r.full)\(d)")
            }
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lines.joined(separator: "\n"), forType: .string)
        notify("Rapport copié", "Le rapport DiskWatch est dans le presse-papiers.")
    }

    func revealDataFolder() {
        NSWorkspace.shared.selectFile(store.configURL.path, inFileViewerRootedAtPath: store.dir.path)
    }

    func resetConfig() {
        config = Config()
    }
}
