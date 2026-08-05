import AppKit

/// Owns every open note window and the note list on disk.
final class NoteManager {
    static let shared = NoteManager()
    private(set) var controllers: [NoteWindowController] = []

    /// Reopen previously saved notes; first run creates one (migrating the old
    /// single-file note if present).
    func restore() {
        var ids = Settings.shared.noteIDs
        if ids.isEmpty {
            let doc = NoteDocument(id: UUID().uuidString)
            // Migrate the old single-file note if it has real content.
            let legacy = (try? String(contentsOf: Storage.legacyNoteURL, encoding: .utf8))
                .flatMap { $0.isEmpty ? nil : $0 }
            doc.save(legacy ?? Storage.starterNote)
            ids = [doc.id]
            Settings.shared.noteIDs = ids
        }
        for id in ids {
            open(NoteDocument(id: id))
        }
    }

    @discardableResult
    func newNote() -> NoteWindowController {
        let doc = NoteDocument(id: UUID().uuidString)
        doc.save("")
        Settings.shared.noteIDs.append(doc.id)
        let controller = open(doc, cascade: true)
        controller.summon()
        return controller
    }

    @discardableResult
    func open(_ document: NoteDocument, cascade: Bool = false) -> NoteWindowController {
        let controller = NoteWindowController(document: document)
        controllers.append(controller)
        if cascade { controller.cascade(index: controllers.count) }
        controller.showWindow()
        return controller
    }

    /// Permanently remove a note and its file (red close button).
    func delete(_ controller: NoteWindowController) {
        controller.panel.orderOut(nil)
        controller.document.delete()
        Settings.shared.noteIDs.removeAll { $0 == controller.document.id }
        controllers.removeAll { $0 === controller }
    }

    func changeFont(by delta: CGFloat) {
        Settings.shared.fontSize = min(28, max(10, Settings.shared.fontSize + delta))
        controllers.forEach { $0.textView.reloadForFontChange() }
    }

    func setFloatingAll(_ floating: Bool) {
        Settings.shared.isFloating = floating
        controllers.forEach { $0.applyMode(floating: floating) }
    }

    func summonAll() {
        NSApp.activate(ignoringOtherApps: true)
        controllers.forEach { $0.panel.orderFrontRegardless() }
        controllers.last?.panel.makeKey()
    }

    func saveAll() {
        controllers.forEach { $0.saveNote() }
    }

    var isFloating: Bool { Settings.shared.isFloating }
}
