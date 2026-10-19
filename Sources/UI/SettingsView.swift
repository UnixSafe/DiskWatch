import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var app: AppState

    var body: some View {
        TabView {
            GeneralTab(app: app)
                .tabItem { Label("Général", systemImage: "gearshape") }
            AlertsTab(app: app)
                .tabItem { Label("Alertes", systemImage: "bell.badge") }
            FoldersTab(app: app)
                .tabItem { Label("Dossiers", systemImage: "folder") }
            AboutTab(app: app)
                .tabItem { Label("À propos", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 620)
    }
}

// MARK: - Général

private struct GeneralTab: View {
    @ObservedObject var app: AppState
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                Picker("Affichage dans la barre", selection: $app.config.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
                }
                Text(app.config.menuBarStyle.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Apparence")
            } footer: {
                Text("Une barre de menus saturée n'affiche pas un élément trop large : macOS lui attribue une position mais ne le dessine pas. Si l'icône disparaît, reviens à la jauge ou à l'icône seule, les deux formats les plus étroits.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Fréquences") {
                Picker("Relevé de l'espace libre", selection: $app.config.sampleIntervalMinutes) {
                    ForEach([1, 2, 5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
                }
                Picker("Mesure des dossiers", selection: $app.config.scanIntervalHours) {
                    ForEach([1, 3, 6, 12, 24], id: \.self) { Text("\($0) h").tag($0) }
                }
                Picker("Conservation de l'historique", selection: $app.config.historyRetentionDays) {
                    ForEach([7, 30, 60, 180, 365], id: \.self) { Text("\($0) jours").tag($0) }
                }
            }

            Section("Démarrage") {
                Toggle("Lancer à l'ouverture de session", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItem.set(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Alertes

private struct AlertsTab: View {
    @ObservedObject var app: AppState

    var body: some View {
        Form {
            Section {
                Toggle("Envoyer des notifications", isOn: $app.config.notificationsEnabled)
            } footer: {
                Text("Sans certificat Developer ID, macOS refuse l'API native et les bannières s'affichent sous l'identité de l'Éditeur de script. Le texte reste celui de DiskWatch.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section {
                ThresholdEditor(values: $app.config.lowSpaceThresholdsGo)
            } header: {
                Text("Seuils d'espace faible")
            } footer: {
                Text("Une alerte par seuil franchi vers le bas. Elle se réarme si l'espace remonte de 8 % au-dessus du seuil.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Détection de dérive") {
                SliderRow(title: "Chute rapide", value: $app.config.spikeGoPerHour,
                          range: 1...20, step: 0.5, unit: "Go en 1 h")
                SliderRow(title: "Baisse continue", value: $app.config.dailyDropGo,
                          range: 5...100, step: 5, unit: "Go sur 24 h")
                SliderRow(title: "Croissance d'un dossier", value: $app.config.folderGrowthGo,
                          range: 1...20, step: 0.5, unit: "Go entre deux mesures")
            }
        }
        .formStyle(.grouped)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value, format: .number.precision(.fractionLength(value == value.rounded() ? 0 : 1))) \(unit)")
                    .font(.system(size: 11, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

private struct ThresholdEditor: View {
    @Binding var values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(values.sorted(by: >).enumerated()), id: \.offset) { index, v in
                HStack {
                    Image(systemName: index == 0 ? "exclamationmark.circle" : "exclamationmark.triangle.fill")
                        .foregroundStyle(index == 0 ? Color.orange : Color.red)
                        .font(.system(size: 11))
                    Text(index == 0 ? "Avertissement" : "Niveau \(index + 1)")
                        .font(.system(size: 11))
                    Spacer()
                    Stepper(value: binding(for: index), in: 1...500, step: 5) {
                        Text("\(Int(values.sorted(by: >)[index])) Go")
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                    Button {
                        var s = values.sorted(by: >)
                        s.remove(at: index)
                        values = s
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(values.count <= 1)
                }
            }

            Button {
                let smallest = values.min() ?? 10
                values = (values + [max(1, smallest / 2)]).sorted(by: >)
            } label: {
                Label("Ajouter un seuil", systemImage: "plus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .disabled(values.count >= 6)
        }
    }

    private func binding(for index: Int) -> Binding<Double> {
        Binding(
            get: { values.sorted(by: >)[index] },
            set: { newValue in
                var s = values.sorted(by: >)
                s[index] = newValue
                values = s.sorted(by: >)
            })
    }
}

// MARK: - Dossiers

private struct FoldersTab: View {
    @ObservedObject var app: AppState
    @State private var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(app.config.watchedPaths, id: \.self) { path in
                    HStack(spacing: 8) {
                        Image(systemName: FileManager.default.fileExists(atPath: Paths.expand(path))
                              ? "folder.fill" : "folder.badge.questionmark")
                            .foregroundStyle(FileManager.default.fileExists(atPath: Paths.expand(path))
                                             ? Color.accentColor : Color.secondary)
                        Text(path)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if let row = app.rows.first(where: { $0.path == path }) {
                            Text(Fmt.size(row.size))
                                .font(.system(size: 10, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(path)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            HStack(spacing: 8) {
                Button { addFolder() } label: { Image(systemName: "plus") }
                Button {
                    if let s = selection {
                        app.config.watchedPaths.removeAll { $0 == s }
                        selection = nil
                    }
                } label: { Image(systemName: "minus") }
                .disabled(selection == nil)

                Spacer()

                Button("Rétablir la sélection par défaut") {
                    app.config.watchedPaths = Config.defaultPaths
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .overlay(alignment: .bottom) {
            Text("Évite d'imbriquer un dossier dans un autre déjà surveillé : les tailles seraient comptées deux fois.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                .opacity(0)
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Surveiller"
        panel.message = "Choisis les dossiers à surveiller"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK else { return }
        let added = panel.urls.map { Paths.abbreviate($0.path) }
        app.config.watchedPaths = Array(Set(app.config.watchedPaths + added)).sorted()
    }
}

// MARK: - À propos

private struct AboutTab: View {
    @ObservedObject var app: AppState
    @State private var confirmReset = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "internaldrive")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.color(app.severity))
                .padding(.top, 24)

            Text("DiskWatch").font(.system(size: 17, weight: .semibold))
            Text("Version \(version)").font(.system(size: 11)).foregroundStyle(.secondary)

            Text("Surveillance de l'espace disque et détection des dossiers qui gonflent.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                stat("Relevés enregistrés", "\(app.history.count)")
                stat("Dossiers surveillés", "\(app.config.watchedPaths.count)")
                if let last = app.lastScan { stat("Dernière mesure", Fmt.age(last)) }
            }
            .padding(.top, 4)

            Spacer()

            HStack(spacing: 10) {
                Button("Ouvrir le dossier de données") { app.revealDataFolder() }
                Button("Rétablir tous les réglages") { confirmReset = true }
            }
            .font(.system(size: 11))
            .padding(.bottom, 18)
            .confirmationDialog("Rétablir tous les réglages par défaut ?",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Rétablir", role: .destructive) { app.resetConfig() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les seuils, fréquences et dossiers surveillés reviendront à leurs valeurs d'origine. L'historique est conservé.")
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 11))
    }
}
