import Foundation

/// One note: a stable id and its Markdown file on disk.
final class NoteDocument {
    let id: String
    let fileURL: URL

    init(id: String) {
        self.id = id
        self.fileURL = Storage.notesDirectory.appendingPathComponent("note-\(id).md")
    }

    func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    func save(_ text: String) {
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
