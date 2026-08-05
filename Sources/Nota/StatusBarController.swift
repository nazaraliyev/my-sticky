import AppKit

/// The menu-bar entry — the only always-available UI, since there is no Dock icon.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Nota")
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let newNote = NSMenuItem(title: "Yeni not", action: #selector(newNote), keyEquivalent: "n")
        newNote.keyEquivalentModifierMask = [.command, .shift]
        newNote.target = self
        menu.addItem(newNote)

        let show = NSMenuItem(title: "Bütün notları göstər  (⌥⌘N)", action: #selector(showNotes), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let float = NSMenuItem(title: "Həmişə üstdə (bütün Spaces)", action: #selector(toggleFloat), keyEquivalent: "")
        float.target = self
        float.state = NoteManager.shared.isFloating ? .on : .off
        menu.addItem(float)

        let login = NSMenuItem(title: "Login-da başlat", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Çıxış", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func newNote() { NoteManager.shared.newNote() }

    @objc private func showNotes() { NoteManager.shared.summonAll() }

    @objc private func toggleFloat() {
        NoteManager.shared.setFloatingAll(!NoteManager.shared.isFloating)
        buildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
        buildMenu()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
