import AppKit

// Agent de barre de menus : aucune icône dans le Dock, aucune fenêtre au lancement.
// Le code de premier niveau n'est pas isolé sur l'acteur principal alors que le
// contrôleur l'est ; NSApplicationMain garantit pourtant qu'on y est déjà.
let application = NSApplication.shared
let controller = MainActor.assumeIsolated { AppController() }
application.delegate = controller
application.setActivationPolicy(.accessory)
application.run()
