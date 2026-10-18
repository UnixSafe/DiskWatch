import Foundation

/// Mesure la taille des dossiers surveillés avec `du`, en basse priorité et en
/// parallèle. Annulable : un scan en cours ne doit pas retarder une fermeture.
final class FolderScanner {
    private let queue = OperationQueue()
    private var cancelled = false
    private let lock = NSLock()

    init() {
        queue.maxConcurrentOperationCount = 6
        queue.qualityOfService = .utility
    }

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        queue.cancelAllOperations()
    }

    /// `progress` est appelé sur une file de travail, jamais sur le thread principal.
    func scan(_ paths: [String], progress: ((Int, Int) -> Void)? = nil) -> [String: Int64] {
        lock.lock(); cancelled = false; lock.unlock()

        var result: [String: Int64] = [:]
        var done = 0
        let total = paths.count
        let guardLock = NSLock()

        for raw in paths {
            queue.addOperation { [weak self] in
                guard let self, !self.isCancelled else { return }
                let full = Paths.expand(raw)
                let bytes = FolderScanner.measure(full)
                guardLock.lock()
                if let bytes { result[raw] = bytes }
                done += 1
                let d = done
                guardLock.unlock()
                progress?(d, total)
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        return isCancelled ? [:] : result
    }

    /// `du -skx` : -s total seul, -k en kibioctets, -x sans franchir les points de montage.
    static func measure(_ path: String) -> Int64? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/nice")
        p.arguments = ["-n", "10", "/usr/bin/du", "-skx", path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        // Lire avant d'attendre : un tube plein bloquerait le processus fils.
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let s = String(data: data, encoding: .utf8) else { return nil }
        for line in s.split(separator: "\n").reversed() {
            let field = line.split(separator: "\t").first?.trimmingCharacters(in: .whitespaces) ?? ""
            if let kb = Int64(field) { return kb * 1024 }
        }
        return nil
    }
}
