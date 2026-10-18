import Foundation

/// Persistance sur disque. L'historique est un JSONL append-only : écrire un
/// relevé coûte une ligne, pas une réécriture du fichier entier.
final class Store {
    let dir: URL
    let configURL: URL
    let historyURL: URL
    let foldersURL: URL
    let stateURL: URL

    private let pretty: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    init() {
        dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DiskWatch", isDirectory: true)
        configURL  = dir.appendingPathComponent("config.json")
        historyURL = dir.appendingPathComponent("history.jsonl")
        foldersURL = dir.appendingPathComponent("folders.json")
        stateURL   = dir.appendingPathComponent("state.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: Réglages

    func loadConfig() -> Config {
        guard let d = try? Data(contentsOf: configURL),
              let c = try? JSONDecoder().decode(Config.self, from: d) else {
            let fresh = Config()
            save(fresh)
            return fresh
        }
        return c
    }

    func save(_ c: Config) {
        if let d = try? pretty.encode(c) { try? d.write(to: configURL, options: .atomic) }
    }

    // MARK: Historique

    func append(_ s: Sample) {
        guard var data = try? JSONEncoder().encode(s) else { return }
        data.append(0x0A)
        if let h = try? FileHandle(forWritingTo: historyURL) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    func loadHistory() -> [Sample] {
        guard let d = try? Data(contentsOf: historyURL),
              let text = String(data: d, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        return text.split(separator: "\n").compactMap {
            guard let line = $0.data(using: .utf8) else { return nil }
            return try? dec.decode(Sample.self, from: line)
        }
    }

    @discardableResult
    func pruneHistory(retentionDays: Int) -> [Sample] {
        let cutoff = Date().timeIntervalSince1970 - Double(retentionDays) * 86400
        let kept = loadHistory().filter { $0.t >= cutoff }
        let enc = JSONEncoder()
        var out = Data()
        for s in kept {
            if var line = try? enc.encode(s) { line.append(0x0A); out.append(line) }
        }
        try? out.write(to: historyURL, options: .atomic)
        return kept
    }

    // MARK: Dossiers et alertes

    func loadFolders() -> FolderStore {
        guard let d = try? Data(contentsOf: foldersURL),
              let f = try? JSONDecoder().decode(FolderStore.self, from: d) else { return FolderStore() }
        return f
    }

    func save(_ f: FolderStore) {
        if let d = try? pretty.encode(f) { try? d.write(to: foldersURL, options: .atomic) }
    }

    func loadState() -> AlertState {
        guard let d = try? Data(contentsOf: stateURL),
              let s = try? JSONDecoder().decode(AlertState.self, from: d) else { return AlertState() }
        return s
    }

    func save(_ s: AlertState) {
        if let d = try? pretty.encode(s) { try? d.write(to: stateURL, options: .atomic) }
    }
}
