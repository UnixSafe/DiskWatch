import Foundation

enum Disk {
    /// Volume de données : sur APFS c'est lui qui porte l'espace utilisateur,
    /// « / » étant un instantané système en lecture seule.
    static let volume = "/System/Volumes/Data"

    /// `attributesOfFileSystem` s'appuie sur statfs ; `systemFreeSize` correspond
    /// à l'espace disponible rapporté par `df`, purgeable exclu.
    static func stats() -> (free: Int64, total: Int64)? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: volume),
              let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value,
              let total = (attrs[.systemSize] as? NSNumber)?.int64Value,
              total > 0 else { return nil }
        return (free, total)
    }

    static func sample() -> Sample? {
        guard let s = stats() else { return nil }
        return Sample(t: Date().timeIntervalSince1970, free: s.free, total: s.total)
    }
}
