import AppKit
import SwiftUI
import Combine

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private let app = AppState()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Cycle de vie

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }

        buildStatusItem()
        buildPopover()
        app.start()

        // L'icône suit l'état : espace restant, gravité, style choisi.
        app.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        updateStatusItem()

        // Le thème système change la couleur neutre de l'icône.
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateStatusItem() }
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        app.shutdown()
    }

    // MARK: Barre de menus

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let style = app.config.menuBarStyle
        let severity = app.severity

        button.image = StatusIcon.image(style: style, ratio: app.trend.usedRatio, severity: severity)
        button.imagePosition = .imageLeading

        let title = StatusIcon.title(style: style, free: app.trend.free)
        if title.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            let color: NSColor = severity == .normal
                ? (Theme.menuBarIsDark ? .white : .black)
                : Theme.nsColor(severity)
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ])
        }

        button.toolTip = "DiskWatch — \(Fmt.size(app.trend.free)) libres sur \(Fmt.size(app.trend.total))"
    }

    // MARK: Panneau

    private func buildPopover() {
        let host = NSHostingController(rootView: PanelView(
            app: app,
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }))
        host.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    /// Clic droit : menu contextuel classique. Le panneau reste sur le clic gauche.
    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return togglePopover() }
        let secondary = event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)
        if secondary { showContextMenu() } else { togglePopover() }
    }

    private func showContextMenu() {
        popover.performClose(nil)
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Réglages…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let report = NSMenuItem(title: "Copier le rapport", action: #selector(menuReport), keyEquivalent: "c")
        report.target = self
        menu.addItem(report)

        let scan = NSMenuItem(title: app.isScanning ? "Analyse en cours…" : "Analyser maintenant",
                              action: #selector(menuScan), keyEquivalent: "r")
        scan.target = self
        scan.isEnabled = !app.isScanning
        menu.addItem(scan)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter DiskWatch",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // popUp plutôt que statusItem.menu : affecter le menu à l'élément ferait
        // ouvrir ce menu au clic gauche, à la place du panneau.
        if let button = statusItem.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 4),
                       in: button)
        }
    }

    @objc private func menuSettings() { openSettings() }
    @objc private func menuReport() { app.copyReport() }
    @objc private func menuScan() { app.scan() }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            app.takeSample()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Sans activation, le panneau ne reçoit ni clavier ni survol fiable.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: Réglages

    private func openSettings() {
        popover.performClose(nil)

        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let host = NSHostingController(rootView: SettingsView(app: app))
        let window = NSWindow(contentViewController: host)
        window.title = "Réglages DiskWatch"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("DiskWatchSettings")
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
