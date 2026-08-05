import AppKit

/// Borderless panel that can still take keyboard focus (needed for text editing).
/// Borderless windows return `false` for these by default, which blocks typing.
final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
