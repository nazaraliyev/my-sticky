import AppKit

/// A single interactive checkbox rendered inline in the editor.
/// It replaces a `[ ]` / `[x]` markdown token; on save it is serialized back.
final class CheckboxAttachment: NSTextAttachment {
    var checked: Bool

    init(checked: Bool) {
        self.checked = checked
        super.init(data: nil, ofType: nil)
        refreshImage()
    }

    required init?(coder: NSCoder) {
        self.checked = false
        super.init(coder: coder)
        refreshImage()
    }

    /// Rebuilds the glyph for the current `checked` state.
    func refreshImage() {
        let symbol = CheckboxAttachment.image(checked: checked)
        image = symbol
        // Nudge down so the box sits centered on the text baseline.
        bounds = CGRect(x: 0, y: -3, width: symbol.size.width, height: symbol.size.height)
    }

    static func image(checked: Bool) -> NSImage {
        let name = checked ? "checkmark.square.fill" : "square"
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            .applying(.init(hierarchicalColor: .systemBlue))
        let base = NSImage(systemSymbolName: name,
                           accessibilityDescription: checked ? "checked" : "unchecked") ?? NSImage()
        return base.withSymbolConfiguration(config) ?? base
    }
}
