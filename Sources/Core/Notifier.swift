import Foundation
import UserNotifications

/// Envoi des alertes. L'app étant signée « ad hoc », macOS refuse souvent
/// l'autorisation UserNotifications ; on retombe alors sur `osascript`, qui
/// affiche la même bannière sous l'identité de l'Éditeur de script.
final class Notifier {
    private var native = false

    func setup() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        native = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// L'autorisation est relue à chaque envoi : un drapeau mis en cache par le
    /// callback asynchrone resterait faux pendant les premières secondes.
    func send(title: String, body: String) {
        guard native else { return Notifier.fallback(title, body) }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let c = UNMutableNotificationContent()
                c.title = title
                c.body = body
                c.sound = .default
                center.add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)) { err in
                    if err != nil { Notifier.fallback(title, body) }
                }
            default:
                Notifier.fallback(title, body)
            }
        }
    }

    private static func fallback(_ title: String, _ body: String) {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "display notification \"\(esc(body))\" with title \"\(esc(title))\""]
        try? p.run()
    }
}
