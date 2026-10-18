import Foundation
import ServiceManagement

/// Lancement à l'ouverture de session. On privilégie SMAppService, qui apparaît
/// dans Réglages Système ▸ Général ▸ Ouverture ; s'il échoue — ce qui arrive
/// avec une signature ad hoc — on écrit un LaunchAgent classique.
enum LoginItem {
    private static let label = "com.unixsafe.diskwatch"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        if SMAppService.mainApp.status == .enabled { return true }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        if on {
            do {
                try SMAppService.mainApp.register()
                return true
            } catch {
                return writeAgent()
            }
        } else {
            try? SMAppService.mainApp.unregister()
            removeAgent()
            return true
        }
    }

    // MARK: Repli LaunchAgent

    private static func writeAgent() -> Bool {
        guard let exe = Bundle.main.executablePath else { return false }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Background",
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        else { return false }
        try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        do { try data.write(to: agentURL, options: .atomic) } catch { return false }
        launchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
        return true
    }

    private static func removeAgent() {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }
        launchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: agentURL)
    }

    private static func launchctl(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
    }
}
