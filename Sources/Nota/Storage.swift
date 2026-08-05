import Foundation

/// Filesystem layout for notes. Each note is a Markdown file so it stays
/// portable and syncable; this type just provides the directory + defaults.
enum Storage {
    static let notesDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Nota", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Pre-multi-note single file; migrated into the first note on first run.
    static let legacyNoteURL = notesDirectory.appendingPathComponent("note.md")

    static let starterNote = """
    # Nota

    - [ ] İlk tapşırıq
    - [x] Bitmiş iş
    - [ ] Başqa bir şey

    **Qalın** və *əyri* mətn avtomatik render olunur.
    Sətrə klik edəndə işarələr görünür ki, redaktə edə biləsən.
    """
}
