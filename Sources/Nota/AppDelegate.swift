import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A hidden main menu so standard editing shortcuts (⌘Z/⌘C/⌘V/⌘A…)
        // keep working even though this is an accessory (no visible menu bar) app.
        NSApp.mainMenu = Self.makeMainMenu()

        NoteManager.shared.restore()
        statusBar = StatusBarController()

        // ⌥⌘N from anywhere brings all notes forward and focuses one.
        GlobalHotKey.shared.register {
            NoteManager.shared.summonAll()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NoteManager.shared.saveAll()
    }

    private static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu — carries ⌘Q.
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Çıxış", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // Edit menu — standard text editing key equivalents.
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        // Format menu — shortcuts route through the responder chain to the note.
        let formatItem = NSMenuItem()
        mainMenu.addItem(formatItem)
        let formatMenu = NSMenu(title: "Format")
        formatMenu.addItem(withTitle: "Qalın", action: #selector(MarkdownTextView.toggleBold(_:)), keyEquivalent: "b")
        formatMenu.addItem(withTitle: "Əyri", action: #selector(MarkdownTextView.toggleItalic(_:)), keyEquivalent: "i")
        formatMenu.addItem(.separator())
        formatMenu.addItem(withTitle: "Şrifti böyüt", action: #selector(MarkdownTextView.notaFontBigger(_:)), keyEquivalent: "=")
        formatMenu.addItem(withTitle: "Şrifti kiçilt", action: #selector(MarkdownTextView.notaFontSmaller(_:)), keyEquivalent: "-")
        formatItem.submenu = formatMenu

        return mainMenu
    }
}
