import AppKit

/// The note editor: live Markdown styling, `[]`→checkbox conversion while typing,
/// click-to-toggle checkboxes, and programmatic actions for the toolbar.
final class MarkdownTextView: NSTextView {
    /// Called after any user-driven change so the controller can autosave.
    var onModelChange: (() -> Void)?

    /// Guards against re-entrancy while we mutate the storage ourselves.
    private var isProgrammatic = false

    private static let bulletContinuation = try? NSRegularExpression(pattern: "^(\\s*)([-*+])\\s+(.*)$")
    private static let orderedContinuation = try? NSRegularExpression(pattern: "^(\\s*)(\\d+)\\.\\s+(.*)$")

    override var canBecomeKeyView: Bool { true }

    // MARK: - Live preview (hide Markdown syntax markers)

    private var lastCaretLineRange = NSRange(location: NSNotFound, length: 0)

    /// Wire this view up as its layout manager's delegate so `shouldGenerateGlyphs`
    /// can null out marker glyphs.
    func enableLivePreview() {
        layoutManager?.delegate = self
    }

    /// The line the caret is on — but only while actually editing. When the view
    /// isn't first responder we return "nowhere" so every marker stays hidden.
    private func revealedLineRange() -> NSRange {
        guard window?.firstResponder === self, let textStorage else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return (textStorage.string as NSString).lineRange(for: selectedRange())
    }

    private func invalidateSyntaxLayout() {
        guard let layoutManager, let textStorage, let textContainer else { return }
        let full = NSRange(location: 0, length: textStorage.length)
        layoutManager.invalidateGlyphs(forCharacterRange: full, changeInLength: 0, actualCharacterRange: nil)
        layoutManager.invalidateLayout(forCharacterRange: full, actualCharacterRange: nil)
        layoutManager.ensureLayout(for: textContainer)
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.invalidateSyntaxLayout() }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.invalidateSyntaxLayout() }
        return result
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
        let line = revealedLineRange()
        if !NSEqualRanges(line, lastCaretLineRange) {
            lastCaretLineRange = line
            DispatchQueue.main.async { [weak self] in self?.invalidateSyntaxLayout() }
        }
    }

    // MARK: - Load / serialize

    func loadMarkdown(_ markdown: String) {
        guard let storage = textStorage else { string = markdown; return }
        isProgrammatic = true
        let renumbered = MarkdownRenderer.renumberingOrderedLists(markdown)
        storage.setAttributedString(MarkdownRenderer.makeAttributedString(from: renumbered))
        typingAttributes = MarkdownRenderer.baseTypingAttributes
        isProgrammatic = false
    }

    func currentMarkdown() -> String {
        guard let storage = textStorage else { return string }
        return MarkdownRenderer.serialize(storage)
    }

    /// Re-render with the current base font (used after a font-size change).
    func reloadForFontChange() {
        let caret = selectedRange()
        loadMarkdown(currentMarkdown())
        setSelectedRange(NSRange(location: min(caret.location, string.count), length: 0))
    }

    // MARK: - Change handling

    override func didChangeText() {
        super.didChangeText()
        guard !isProgrammatic, let storage = textStorage else { return }
        convertMarkerBeforeCaret()
        renumberOrderedLists()
        MarkdownRenderer.applyStyling(to: storage)
        onModelChange?()
    }

    /// Rewrite out-of-sequence ordered-list numbers (after deleting, inserting or
    /// pasting items), keeping the selection on the same text.
    private func renumberOrderedLists() {
        guard let storage = textStorage else { return }
        // Undo/redo restores text that was already numbered; editing mid-undo would corrupt the stack.
        if let undoManager, undoManager.isUndoing || undoManager.isRedoing { return }
        let fixes = MarkdownRenderer.orderedListFixes(in: storage.string)
        guard !fixes.isEmpty else { return }

        // Map a pre-edit index to its post-edit position (fixes are in ascending order).
        func shifted(_ index: Int) -> Int {
            var result = index
            for fix in fixes where fix.range.location < index {
                let newLength = (String(fix.number) as NSString).length
                let offset = index - fix.range.location
                result += offset >= fix.range.length ? newLength - fix.range.length : min(offset, newLength) - offset
            }
            return result
        }
        let sel = selectedRange()
        let start = shifted(sel.location)
        let end = shifted(sel.location + sel.length)

        isProgrammatic = true
        for fix in fixes.reversed() {
            let number = String(fix.number)
            guard shouldChangeText(in: fix.range, replacementString: number) else { continue }
            storage.replaceCharacters(in: fix.range, with: NSAttributedString(string: number, attributes: MarkdownRenderer.baseTypingAttributes))
            didChangeText()
        }
        isProgrammatic = false
        setSelectedRange(NSRange(location: min(start, storage.length), length: max(0, min(end, storage.length) - start)))
    }

    private func convertMarkerBeforeCaret() {
        guard let storage = textStorage else { return }
        let caret = selectedRange().location
        let ns = storage.string as NSString
        guard caret <= ns.length else { return }
        for tokenLength in [3, 2] where caret >= tokenLength {
            let range = NSRange(location: caret - tokenLength, length: tokenLength)
            let token = ns.substring(with: range)
            guard let checked = MarkdownRenderer.checkboxState(forToken: token) else { continue }
            replaceWithCheckbox(range: range, checked: checked)
            return
        }
    }

    private func replaceWithCheckbox(range: NSRange, checked: Bool) {
        guard let storage = textStorage else { return }
        let cb = CheckboxAttachment(checked: checked)
        isProgrammatic = true
        if shouldChangeText(in: range, replacementString: "\u{FFFC}") {
            storage.replaceCharacters(in: range, with: NSAttributedString(attachment: cb))
            didChangeText()
        }
        isProgrammatic = false
        setSelectedRange(NSRange(location: range.location + 1, length: 0))
        typingAttributes = MarkdownRenderer.baseTypingAttributes
    }

    // MARK: - List continuation on Enter

    override func insertNewline(_ sender: Any?) {
        if handleListContinuation() { return }
        super.insertNewline(sender)
    }

    /// Enter inside a checkbox/bullet/ordered item continues the list; Enter on
    /// an empty item removes the marker (turns it back into plain text).
    private func handleListContinuation() -> Bool {
        guard let storage = textStorage else { return false }
        let sel = selectedRange()
        guard sel.length == 0 else { return false }
        let ns = storage.string as NSString
        var lineRange = ns.lineRange(for: NSRange(location: sel.location, length: 0))
        if lineRange.length > 0,
           ns.substring(with: NSRange(location: lineRange.location + lineRange.length - 1, length: 1)) == "\n" {
            lineRange.length -= 1
        }
        let lineEnd = lineRange.location + lineRange.length
        let lineStr = ns.substring(with: lineRange)
        let indent = String(lineStr.prefix { $0 == " " || $0 == "\t" })
        let markerStart = lineRange.location + (indent as NSString).length
        let lineNSLength = (lineStr as NSString).length

        // Checkbox item (an attachment at line start)
        if markerStart < storage.length,
           storage.attribute(.attachment, at: markerStart, effectiveRange: nil) is CheckboxAttachment {
            var contentStart = markerStart + 1
            if contentStart < ns.length,
               ns.substring(with: NSRange(location: contentStart, length: 1)) == " " {
                contentStart += 1
            }
            let content = contentStart <= lineEnd
                ? ns.substring(with: NSRange(location: contentStart, length: lineEnd - contentStart))
                : ""
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                applyProgrammatic(NSAttributedString(string: ""),
                                  replacing: NSRange(location: markerStart, length: lineEnd - markerStart),
                                  caretAfter: markerStart)
            } else {
                let insertion = NSMutableAttributedString(string: "\n" + indent, attributes: MarkdownRenderer.baseTypingAttributes)
                insertion.append(NSAttributedString(attachment: CheckboxAttachment(checked: false)))
                insertion.append(NSAttributedString(string: " ", attributes: MarkdownRenderer.baseTypingAttributes))
                applyProgrammatic(insertion, replacing: NSRange(location: sel.location, length: 0),
                                  caretAfter: sel.location + insertion.length)
            }
            return true
        }

        // Bullet item
        if let regex = Self.bulletContinuation,
           let match = regex.firstMatch(in: lineStr, range: NSRange(location: 0, length: lineNSLength)) {
            let content = (lineStr as NSString).substring(with: match.range(at: 3))
            let marker = (lineStr as NSString).substring(with: match.range(at: 2))
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                applyProgrammatic(NSAttributedString(string: ""),
                                  replacing: NSRange(location: markerStart, length: lineEnd - markerStart),
                                  caretAfter: markerStart)
            } else {
                let text = "\n" + indent + marker + " "
                applyProgrammatic(NSAttributedString(string: text, attributes: MarkdownRenderer.baseTypingAttributes),
                                  replacing: NSRange(location: sel.location, length: 0),
                                  caretAfter: sel.location + (text as NSString).length)
            }
            return true
        }

        // Ordered item
        if let regex = Self.orderedContinuation,
           let match = regex.firstMatch(in: lineStr, range: NSRange(location: 0, length: lineNSLength)) {
            let content = (lineStr as NSString).substring(with: match.range(at: 3))
            let number = Int((lineStr as NSString).substring(with: match.range(at: 2))) ?? 1
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                applyProgrammatic(NSAttributedString(string: ""),
                                  replacing: NSRange(location: markerStart, length: lineEnd - markerStart),
                                  caretAfter: markerStart)
            } else {
                let text = "\n" + indent + "\(number + 1). "
                applyProgrammatic(NSAttributedString(string: text, attributes: MarkdownRenderer.baseTypingAttributes),
                                  replacing: NSRange(location: sel.location, length: 0),
                                  caretAfter: sel.location + (text as NSString).length)
            }
            return true
        }

        return false
    }

    // MARK: - Click to toggle

    override func mouseDown(with event: NSEvent) {
        if let index = checkboxIndex(at: event),
           let storage = textStorage,
           let cb = storage.attribute(.attachment, at: index, effectiveRange: nil) as? CheckboxAttachment {
            toggleCheckbox(cb, at: index)
            return
        }
        super.mouseDown(with: event)
    }

    private func checkboxIndex(at event: NSEvent) -> Int? {
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0 else { return nil }
        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerInset.width
        point.y -= textContainerInset.height
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard glyphRect.contains(point) else { return nil }
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        return charIndex < storage.length ? charIndex : nil
    }

    private func toggleCheckbox(_ cb: CheckboxAttachment, at index: Int) {
        guard let storage = textStorage else { return }
        let range = NSRange(location: index, length: 1)
        cb.checked.toggle()
        cb.refreshImage()
        isProgrammatic = true
        if shouldChangeText(in: range, replacementString: "\u{FFFC}") {
            storage.replaceCharacters(in: range, with: NSAttributedString(attachment: cb))
            didChangeText()
        }
        isProgrammatic = false
        MarkdownRenderer.applyStyling(to: storage)
        onModelChange?()
    }

    // MARK: - Toolbar actions

    /// Insert an interactive checkbox on its own line at the caret.
    func insertCheckbox() {
        guard let storage = textStorage else { return }
        let caret = selectedRange()
        let ns = storage.string as NSString
        var needsNewline = false
        if caret.location > 0 {
            let prev = ns.substring(with: NSRange(location: caret.location - 1, length: 1))
            needsNewline = prev != "\n"
        }
        let insertion = NSMutableAttributedString(string: needsNewline ? "\n" : "",
                                                  attributes: MarkdownRenderer.baseTypingAttributes)
        insertion.append(NSAttributedString(attachment: CheckboxAttachment(checked: false)))
        insertion.append(NSAttributedString(string: " ", attributes: MarkdownRenderer.baseTypingAttributes))
        applyProgrammatic(insertion, replacing: caret, caretAfter: caret.location + insertion.length)
    }

    /// Wrap the selection with a symmetric marker (e.g. `**`), or insert a placeholder.
    func wrapSelection(with marker: String, placeholder: String) {
        wrap(prefix: marker, suffix: marker, placeholder: placeholder)
    }

    /// Wrap the selection with `prefix`…`suffix`, or insert a placeholder if empty.
    func wrap(prefix: String, suffix: String, placeholder: String) {
        guard let storage = textStorage else { return }
        let range = selectedRange()
        let selected = (storage.string as NSString).substring(with: range)
        let inner = selected.isEmpty ? placeholder : selected
        let text = prefix + inner + suffix
        let attr = NSAttributedString(string: text, attributes: MarkdownRenderer.baseTypingAttributes)
        let caret = selected.isEmpty
            ? range.location + (prefix as NSString).length
            : range.location + (text as NSString).length
        applyProgrammatic(attr, replacing: range, caretAfter: caret,
                          selectLength: selected.isEmpty ? (placeholder as NSString).length : 0)
    }

    /// Toggle a line prefix (`> `, `- `, `1. `…) at the caret's line.
    func toggleLinePrefix(_ prefix: String) {
        guard let storage = textStorage else { return }
        let ns = storage.string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        let lineStr = ns.substring(with: lineRange)
        let whitespace = String(lineStr.prefix { $0 == " " || $0 == "\t" })
        let insertLoc = lineRange.location + (whitespace as NSString).length
        let afterWhitespace = String(lineStr.dropFirst(whitespace.count))
        let prefixLength = (prefix as NSString).length
        if afterWhitespace.hasPrefix(prefix) {
            applyProgrammatic(NSAttributedString(string: ""),
                              replacing: NSRange(location: insertLoc, length: prefixLength),
                              caretAfter: max(insertLoc, selectedRange().location - prefixLength))
        } else {
            applyProgrammatic(NSAttributedString(string: prefix, attributes: MarkdownRenderer.baseTypingAttributes),
                              replacing: NSRange(location: insertLoc, length: 0),
                              caretAfter: selectedRange().location + prefixLength)
        }
    }

    /// Set the caret line's heading level (1–3, or 0 to remove).
    func applyHeading(level: Int) {
        guard let storage = textStorage else { return }
        let ns = storage.string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        let lineStr = ns.substring(with: lineRange)
        let hashes = lineStr.prefix { $0 == "#" }.count
        var existing = 0
        if hashes > 0 {
            existing = hashes + lineStr.dropFirst(hashes).prefix { $0 == " " }.count
        }
        let newPrefix = level == 0 ? "" : String(repeating: "#", count: level) + " "
        let delta = (newPrefix as NSString).length - existing
        applyProgrammatic(NSAttributedString(string: newPrefix, attributes: MarkdownRenderer.baseTypingAttributes),
                          replacing: NSRange(location: lineRange.location, length: existing),
                          caretAfter: max(lineRange.location, selectedRange().location + delta))
    }

    /// Insert a Markdown link, selecting the placeholder URL.
    func insertLink() {
        guard let storage = textStorage else { return }
        let range = selectedRange()
        let selected = (storage.string as NSString).substring(with: range)
        let text = selected.isEmpty ? "mətn" : selected
        let full = "[\(text)](url)"
        let urlStart = range.location + (("[\(text)](") as NSString).length
        applyProgrammatic(NSAttributedString(string: full, attributes: MarkdownRenderer.baseTypingAttributes),
                          replacing: range, caretAfter: urlStart, selectLength: 3)
    }

    // MARK: - Menu / keyboard shortcuts (route via the responder chain)

    @objc func toggleBold(_ sender: Any?) { wrapSelection(with: "**", placeholder: "qalın") }
    @objc func toggleItalic(_ sender: Any?) { wrapSelection(with: "*", placeholder: "əyri") }
    @objc func notaFontBigger(_ sender: Any?) { NoteManager.shared.changeFont(by: 1) }
    @objc func notaFontSmaller(_ sender: Any?) { NoteManager.shared.changeFont(by: -1) }

    private func applyProgrammatic(_ attributed: NSAttributedString, replacing range: NSRange, caretAfter: Int, selectLength: Int = 0) {
        guard let storage = textStorage else { return }
        isProgrammatic = true
        if shouldChangeText(in: range, replacementString: attributed.string) {
            storage.replaceCharacters(in: range, with: attributed)
            didChangeText()
        }
        isProgrammatic = false
        setSelectedRange(NSRange(location: min(caretAfter, storage.length), length: selectLength))
        renumberOrderedLists()
        typingAttributes = MarkdownRenderer.baseTypingAttributes
        MarkdownRenderer.applyStyling(to: storage)
        onModelChange?()
    }
}

// MARK: - Hide syntax markers via null glyphs

extension MarkdownTextView: NSLayoutManagerDelegate {
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes: UnsafePointer<Int>,
                       font: NSFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard let textStorage else { return 0 }
        let revealed = revealedLineRange()
        let count = glyphRange.length
        var props = [NSLayoutManager.GlyphProperty](repeating: [], count: count)
        var changed = false
        for i in 0..<count {
            let charIndex = characterIndexes[i]
            let hide = charIndex < textStorage.length
                && textStorage.attribute(.syntaxMarker, at: charIndex, effectiveRange: nil) != nil
                && !NSLocationInRange(charIndex, revealed)
            if hide {
                props[i] = .null
                changed = true
            } else {
                props[i] = properties[i]
            }
        }
        guard changed else { return 0 }
        layoutManager.setGlyphs(glyphs, properties: &props, characterIndexes: characterIndexes, font: font, forGlyphRange: glyphRange)
        return count
    }
}

