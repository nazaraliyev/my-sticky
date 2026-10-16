import AppKit

extension NSAttributedString.Key {
    /// Marks Markdown syntax characters (`**`, `*`, `#` …) so the editor can
    /// hide them when the caret isn't on that line (live-preview rendering).
    static let syntaxMarker = NSAttributedString.Key("notaSyntaxMarker")
}

/// Bridges between the Markdown source string and the styled, checkbox-bearing
/// attributed string shown in the editor.
///
/// Design: inline styles (headings/bold/italic/strikethrough) keep the literal
/// Markdown characters in place and only add display attributes, so the text is
/// always valid Markdown. Checkboxes are the only element that *replaces*
/// characters (with an attachment), so serialization only has to turn each
/// `CheckboxAttachment` back into `[ ]` / `[x]`.
enum MarkdownRenderer {
    static var baseFont: NSFont { NSFont.systemFont(ofSize: Settings.shared.fontSize) }

    /// Line + paragraph spacing so lines aren't cramped together.
    static var baseParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 4
        return style
    }

    static var baseTypingAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: baseParagraphStyle]
    }

    private static let tokenRegex = try? NSRegularExpression(pattern: "\\[[ xX]?\\]")
    private static let headingRegex = try? NSRegularExpression(pattern: "^(#{1,6})\\s+")
    private static let boldRegex = try? NSRegularExpression(pattern: "\\*\\*([^*\\n]+)\\*\\*")
    private static let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)")
    private static let underscoreItalicRegex = try? NSRegularExpression(pattern: "(?<!_)_([^_\\n]+)_(?!_)")
    private static let strikeRegex = try? NSRegularExpression(pattern: "~~([^~\\n]+)~~")
    private static let codeRegex = try? NSRegularExpression(pattern: "`([^`\\n]+)`")
    private static let underlineRegex = try? NSRegularExpression(pattern: "<u>([^<\\n]*)</u>")
    private static let bulletMarkerRegex = try? NSRegularExpression(pattern: "^(\\s*)([-*+])\\s")
    private static let orderedMarkerRegex = try? NSRegularExpression(pattern: "^(\\s*)(\\d+\\.)\\s")
    private static let orderedItemRegex = try? NSRegularExpression(pattern: "^([ \\t]*)(\\d+)\\.\\s")

    // MARK: - Ordered-list numbering

    /// Ordered-list numbers that are out of sequence: the range of each wrong number
    /// and the number it should be. Consecutive `N.` lines at the same indent count
    /// 1, 2, 3…; deeper-indented lines nest without breaking the outer list, while a
    /// blank line or any other line at the same or shallower indent ends it.
    static func orderedListFixes(in text: String) -> [(range: NSRange, number: Int)] {
        guard let orderedItemRegex else { return [] }
        let ns = text as NSString
        var fixes: [(range: NSRange, number: Int)] = []
        var levels: [(indent: Int, count: Int)] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byLines) { line, lineRange, _, _ in
            guard let line else { return }
            let whitespace = line.prefix { $0 == " " || $0 == "\t" }
            guard whitespace.count < line.count else { levels.removeAll(); return }
            let indent = whitespace.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            guard let m = orderedItemRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
                while let last = levels.last, last.indent >= indent { levels.removeLast() }
                return
            }
            while let last = levels.last, last.indent > indent { levels.removeLast() }
            if let last = levels.last, last.indent == indent {
                levels[levels.count - 1].count += 1
            } else {
                levels.append((indent, 1))
            }
            let expected = levels[levels.count - 1].count
            let digits = m.range(at: 2)
            if Int((line as NSString).substring(with: digits)) != expected {
                fixes.append((NSRange(location: lineRange.location + digits.location, length: digits.length), expected))
            }
        }
        return fixes
    }

    /// `markdown` with every ordered list numbered 1, 2, 3… (see `orderedListFixes`).
    static func renumberingOrderedLists(_ markdown: String) -> String {
        let result = NSMutableString(string: markdown)
        for fix in orderedListFixes(in: markdown).reversed() {
            result.replaceCharacters(in: fix.range, with: String(fix.number))
        }
        return result as String
    }

    // MARK: - Token helpers

    /// Maps a raw token typed by the user to a checkbox state, or nil if not a checkbox.
    static func checkboxState(forToken token: String) -> Bool? {
        switch token {
        case "[]", "[ ]": return false
        case "[x]", "[X]": return true
        default: return nil
        }
    }

    // MARK: - Markdown -> attributed (with attachments)

    static func makeAttributedString(from markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: markdown, attributes: baseTypingAttributes)
        if let tokenRegex {
            let ns = markdown as NSString
            let full = NSRange(location: 0, length: ns.length)
            // Replace back-to-front so earlier ranges stay valid.
            for match in tokenRegex.matches(in: markdown, range: full).reversed() {
                let token = ns.substring(with: match.range)
                let checked = token.lowercased().contains("x")
                let cb = CheckboxAttachment(checked: checked)
                result.replaceCharacters(in: match.range, with: NSAttributedString(attachment: cb))
            }
        }
        styleAttributes(in: result)
        return result
    }

    // MARK: - Attributed -> markdown

    static func serialize(_ storage: NSTextStorage) -> String {
        let full = NSRange(location: 0, length: storage.length)
        let ns = storage.string as NSString
        var out = ""
        storage.enumerateAttribute(.attachment, in: full, options: []) { value, range, _ in
            if let cb = value as? CheckboxAttachment {
                out += cb.checked ? "[x]" : "[ ]"
            } else {
                out += ns.substring(with: range)
            }
        }
        return out
    }

    // MARK: - Styling (attributes only, no character changes)

    static func applyStyling(to storage: NSTextStorage) {
        storage.beginEditing()
        styleAttributes(in: storage)
        storage.endEditing()
    }

    static func styleAttributes(in storage: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: storage.length)
        guard full.length > 0 else { return }

        // Reset to base every pass so removed markup reverts.
        storage.addAttribute(.font, value: baseFont, range: full)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        storage.addAttribute(.paragraphStyle, value: baseParagraphStyle, range: full)
        storage.removeAttribute(.strikethroughStyle, range: full)
        storage.removeAttribute(.underlineStyle, range: full)
        storage.removeAttribute(.backgroundColor, range: full)
        storage.removeAttribute(.syntaxMarker, range: full)

        let ns = storage.string as NSString
        ns.enumerateSubstrings(in: full, options: .byLines) { line, lineRange, _, _ in
            guard let line else { return }
            let lineFull = NSRange(location: 0, length: (line as NSString).length)

            // Headings: bigger/heavier for the whole line.
            if let m = headingRegex?.firstMatch(in: line, range: lineFull) {
                storage.addAttribute(.font, value: headingFont(level: m.range(at: 1).length), range: lineRange)
                let markerRange = NSRange(location: lineRange.location + m.range.location, length: m.range.length)
                storage.addAttribute(.syntaxMarker, value: true, range: markerRange)
            }

            // Blockquote: hide the "> " marker, dim + indent the line.
            if line.hasPrefix(">") {
                let gt = line.prefix { $0 == ">" }.count
                let spaces = line.dropFirst(gt).prefix { $0 == " " }.count
                let prefixLength = gt + spaces
                storage.addAttribute(.syntaxMarker, value: true, range: NSRange(location: lineRange.location, length: prefixLength))
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                let quoteStyle = (baseParagraphStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                quoteStyle.firstLineHeadIndent = 14
                quoteStyle.headIndent = 14
                storage.addAttribute(.paragraphStyle, value: quoteStyle, range: lineRange)
            }

            // List markers (- , * , 1. …) in blue.
            if let m = bulletMarkerRegex?.firstMatch(in: line, range: lineFull) {
                let r = m.range(at: 2)
                storage.addAttribute(.foregroundColor, value: NSColor.systemBlue,
                                     range: NSRange(location: lineRange.location + r.location, length: r.length))
            } else if let m = orderedMarkerRegex?.firstMatch(in: line, range: lineFull) {
                let r = m.range(at: 2)
                storage.addAttribute(.foregroundColor, value: NSColor.systemBlue,
                                     range: NSRange(location: lineRange.location + r.location, length: r.length))
            }

            // Checked line: strike + dim.
            var checked = false
            storage.enumerateAttribute(.attachment, in: lineRange, options: []) { value, _, stop in
                if let cb = value as? CheckboxAttachment, cb.checked {
                    checked = true
                    stop.pointee = true
                }
            }
            if checked {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
            }
        }

        applyInline(boldRegex, in: storage, trait: .boldFontMask, markerLength: 2)
        applyInline(italicRegex, in: storage, trait: .italicFontMask, markerLength: 1)
        applyInline(underscoreItalicRegex, in: storage, trait: .italicFontMask, markerLength: 1)

        applyDecoration(strikeRegex, in: storage, markerLength: 2) { inner in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: inner)
        }
        applyDecoration(codeRegex, in: storage, markerLength: 1) { inner in
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: Settings.shared.fontSize, weight: .regular), range: inner)
            storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: inner)
        }
        applyUnderline(in: storage)
    }

    private static func applyInline(_ regex: NSRegularExpression?, in storage: NSMutableAttributedString, trait: NSFontTraitMask, markerLength: Int) {
        guard let regex else { return }
        let full = NSRange(location: 0, length: storage.length)
        for match in regex.matches(in: storage.string, range: full) {
            let range = match.range
            let existing = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont) ?? baseFont
            storage.addAttribute(.font, value: NSFontManager.shared.convert(existing, toHaveTrait: trait), range: range)
            // Mark the surrounding markers so the editor can hide them.
            let lead = NSRange(location: range.location, length: markerLength)
            let trail = NSRange(location: range.location + range.length - markerLength, length: markerLength)
            storage.addAttribute(.syntaxMarker, value: true, range: lead)
            storage.addAttribute(.syntaxMarker, value: true, range: trail)
        }
    }

    /// Apply an arbitrary decoration to the inner text of a symmetric marker
    /// (e.g. `~~`, `` ` ``) and hide the markers.
    private static func applyDecoration(_ regex: NSRegularExpression?, in storage: NSMutableAttributedString, markerLength: Int, decorate: (NSRange) -> Void) {
        guard let regex else { return }
        let full = NSRange(location: 0, length: storage.length)
        for match in regex.matches(in: storage.string, range: full) {
            let range = match.range
            let inner = NSRange(location: range.location + markerLength, length: max(0, range.length - 2 * markerLength))
            decorate(inner)
            storage.addAttribute(.syntaxMarker, value: true, range: NSRange(location: range.location, length: markerLength))
            storage.addAttribute(.syntaxMarker, value: true, range: NSRange(location: range.location + range.length - markerLength, length: markerLength))
        }
    }

    /// Underline via `<u>…</u>` (asymmetric markers).
    private static func applyUnderline(in storage: NSMutableAttributedString) {
        guard let regex = underlineRegex else { return }
        let full = NSRange(location: 0, length: storage.length)
        let openLength = 3, closeLength = 4
        for match in regex.matches(in: storage.string, range: full) {
            let range = match.range
            guard range.length >= openLength + closeLength else { continue }
            let inner = NSRange(location: range.location + openLength, length: range.length - openLength - closeLength)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: inner)
            storage.addAttribute(.syntaxMarker, value: true, range: NSRange(location: range.location, length: openLength))
            storage.addAttribute(.syntaxMarker, value: true, range: NSRange(location: range.location + range.length - closeLength, length: closeLength))
        }
    }

    private static func headingFont(level: Int) -> NSFont {
        let base = Settings.shared.fontSize
        switch level {
        case 1: return NSFont.systemFont(ofSize: base + 8, weight: .bold)
        case 2: return NSFont.systemFont(ofSize: base + 4, weight: .semibold)
        default: return NSFont.systemFont(ofSize: base + 1, weight: .semibold)
        }
    }
}
