import Cocoa
import AudioUnitPlugin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: SwiftAudioUnitViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "Quit Swift Audio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = applicationMenu
        // Standard responder-chain actions are needed for numeric text fields.
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        editItem.submenu = editMenu
        NSApp.mainMenu = menu
        do {
            let controller = SwiftAudioUnitViewController()
            _ = try controller.createAudioUnit(with: SwiftAudioPluginFactory.componentDescription)
            let window = NSWindow(contentViewController: controller)
            window.title = "Swift Audio — Controls Preview (use Logic Pro for audio)"
            window.setContentSize(NSSize(width: 760, height: 640))
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.controller = controller
            self.window = window
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct SwiftAudioApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
