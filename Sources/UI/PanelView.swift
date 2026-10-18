import SwiftUI
import Charts

enum ChartRange: String, CaseIterable, Identifiable {
    case day = "24 h", week = "7 j", month = "30 j"
    var id: String { rawValue }
    var hours: Double {
        switch self {
        case .day: return 24
        case .week: return 24 * 7
        case .month: return 24 * 30
        }
    }
}

struct PanelView: View {
    @ObservedObject var app: AppState
    @State private var range: ChartRange = .day
    @State private var hovered: String?

    var onSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            chartSection
            Divider().opacity(0.5)
            foldersSection
            Divider().opacity(0.5)
            footer
        }
        .frame(width: Theme.panelWidth)
        .background(.clear)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            CapacityRing(ratio: app.trend.usedRatio, color: Theme.color(app.severity))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.size(app.trend.free))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("libres sur \(Fmt.size(app.trend.total)) · \(Fmt.percent(app.trend.usedRatio)) occupé")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let t = app.trend.timeToFull {
                    Label("Saturation dans \(Fmt.duration(t)) à ce rythme", systemImage: "clock.badge.exclamationmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .animation(.smooth(duration: 0.35), value: app.trend.free)
    }

    // MARK: Graphique

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $range) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 170)
                Spacer()
                if let r = app.trend.ratePerHour {
                    Text(Fmt.rate(r))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(r < 0 ? .orange : .secondary)
                }
            }

            TrendChart(samples: app.window(hours: range.hours), color: Theme.color(app.severity))
                .frame(height: 68)
                .animation(.smooth(duration: 0.4), value: range)

            DeltaStrip(trend: app.trend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Dossiers

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Dossiers surveillés")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if app.isScanning {
                    ProgressView(value: app.scanProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                    Button("Arrêter") { app.cancelScan() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Button { app.scan() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Relancer la mesure")
                }
            }

            if app.rows.isEmpty {
                Text(app.isScanning ? "Première mesure en cours…" : "Aucune mesure. Ajoute des dossiers dans les réglages.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                let shown = Array(app.rows.prefix(14))
                let maxSize = shown.map(\.size).max() ?? 1
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(shown) { row in
                            FolderRowView(row: row, maxSize: maxSize,
                                          highlight: (row.delta.map { Fmt.go($0) >= app.config.folderGrowthGo }) ?? false,
                                          hovered: hovered == row.id)
                            .onHover { hovered = $0 ? row.id : nil }
                        }
                    }
                }
                .frame(maxHeight: 238)
                .scrollIndicators(.automatic)

                if let last = app.lastScan {
                    Text(app.previousScan == nil
                         ? "Mesurés \(Fmt.age(last)) — variations au prochain passage"
                         : "Mesurés \(Fmt.age(last))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Pied

    private var footer: some View {
        HStack(spacing: 10) {
            Button { app.copyReport() } label: {
                Label("Copier le rapport", systemImage: "doc.on.clipboard")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Réglages")

            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Quitter DiskWatch")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Anneau de capacité

struct CapacityRing: View {
    let ratio: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.16), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(ratio, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.5), value: ratio)
            Text(Fmt.percent(ratio).replacingOccurrences(of: " %", with: ""))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Courbe

struct TrendChart: View {
    let samples: [Sample]
    let color: Color

    var body: some View {
        if samples.count < 2 {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.4))
                .overlay(
                    Text("Historique en constitution…")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary))
        } else {
            let values = samples.map { Double($0.free) }
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            // Au moins 1 Go d'amplitude : sinon le bruit ressemble à une falaise.
            let pad = max((hi - lo) * 0.18, 1_000_000_000 * 0.5)

            Chart(samples) { s in
                AreaMark(x: .value("Instant", s.date), y: .value("Libre", s.free))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.areaFill(color))
                LineMark(x: .value("Instant", s.date), y: .value("Libre", s.free))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    .foregroundStyle(color)
            }
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(.quaternary.opacity(0.5))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { value in
                    AxisGridLine().foregroundStyle(.quaternary.opacity(0.5))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.size(Int64(v), decimals: 0))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Variations

struct DeltaStrip: View {
    let trend: Trend

    var body: some View {
        HStack(spacing: 14) {
            item("1 h", trend.delta1h)
            item("24 h", trend.delta24h)
            item("7 j", trend.delta7d)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func item(_ label: String, _ value: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(Fmt.deltaOrDash(value))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color(value))
        }
    }

    private func color(_ v: Int64?) -> Color {
        guard let v else { return .secondary }
        if v < -2_000_000_000 { return .orange }
        if v > 2_000_000_000 { return .green }
        return .secondary
    }
}

// MARK: - Ligne de dossier

struct FolderRowView: View {
    let row: FolderRow
    let maxSize: Int64
    let highlight: Bool
    let hovered: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(row.display)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Fmt.size(row.size))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)

            Text(Fmt.deltaOrDash(row.delta))
                .font(.system(size: 10, weight: highlight ? .semibold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? Color.orange : Color.secondary.opacity(0.65))
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 5)
        .overlay(alignment: .bottomLeading) {
            // Filet de proportion : lisible sans concurrencer le texte.
            GeometryReader { geo in
                Capsule()
                    .fill(highlight ? Color.orange.opacity(0.7) : Color.accentColor.opacity(0.45))
                    .frame(width: max(2, geo.size.width * CGFloat(Double(row.size) / Double(max(maxSize, 1)))),
                           height: 2)
                    .offset(y: geo.size.height - 2)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary.opacity(hovered ? 0.5 : 0))
        }
        .help(row.full)
    }
}
