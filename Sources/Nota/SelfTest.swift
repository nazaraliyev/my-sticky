import AppKit

/// Headless sanity check for the Markdown ⇄ attributed-string round-trip and
/// checkbox toggling. Run with `Nota --selftest`.
enum SelfTest {
    static func run() {
        var pass = true
        func check(_ condition: Bool, _ label: String) {
            print((condition ? "✅" : "❌") + " " + label)
            if !condition { pass = false }
        }

        let markdown = """
        # Başlıq
        - [ ] birinci
        - [x] ikinci
        **qalın** və *əyri*
        """

        let storage = NSTextStorage()
        storage.setAttributedString(MarkdownRenderer.makeAttributedString(from: markdown))

        var boxes: [CheckboxAttachment] = []
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let cb = value as? CheckboxAttachment { boxes.append(cb) }
        }
        check(boxes.count == 2, "iki checkbox render olundu (tapıldı: \(boxes.count))")
        check(boxes.first?.checked == false && boxes.last?.checked == true, "checkbox halları düzgün oxundu")

        let roundTripped = MarkdownRenderer.serialize(storage)
        check(roundTripped == markdown, "round-trip mətni dəyişmədən qaytardı")

        boxes.first?.checked = true
        let toggled = MarkdownRenderer.serialize(storage)
        check(toggled.contains("- [x] birinci"), "toggle sonrası markdown [x] oldu")

        // Live-preview: markers tagged for hiding, inner text styled, round-trip intact.
        let bold = NSTextStorage()
        bold.setAttributedString(MarkdownRenderer.makeAttributedString(from: "**qalın**"))
        let leadMarker = bold.attribute(.syntaxMarker, at: 0, effectiveRange: nil) != nil
        let trailMarker = bold.attribute(.syntaxMarker, at: bold.length - 1, effectiveRange: nil) != nil
        let midFont = bold.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        let midBold = midFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
        check(leadMarker && trailMarker, "** işarələri gizlətmək üçün qeyd olundu")
        check(midBold, "daxildəki mətn qalın oldu")
        check(MarkdownRenderer.serialize(bold) == "**qalın**", "qalın round-trip qorundu")

        // Strikethrough / code render markers + round-trip.
        let strike = NSTextStorage()
        strike.setAttributedString(MarkdownRenderer.makeAttributedString(from: "~~x~~"))
        check(strike.attribute(.syntaxMarker, at: 0, effectiveRange: nil) != nil, "~~ gizlətmək üçün qeyd olundu")
        check(MarkdownRenderer.serialize(strike) == "~~x~~", "strike round-trip qorundu")

        // List marker coloured (blue), not default text colour.
        let bulletDoc = NSTextStorage()
        bulletDoc.setAttributedString(MarkdownRenderer.makeAttributedString(from: "- item"))
        let bulletColor = bulletDoc.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        check(bulletColor != nil && bulletColor != NSColor.labelColor, "bullet markeri rəngləndi (mavi)")

        // Interactive editing logic (headless MarkdownTextView).
        func edited(_ md: String, _ apply: (MarkdownTextView) -> Void) -> String {
            let tv = MarkdownTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
            tv.loadMarkdown(md)
            apply(tv)
            return tv.currentMarkdown()
        }
        func end(_ tv: MarkdownTextView) { tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0)) }

        check(edited("- item") { tv in end(tv); tv.insertNewline(nil) } == "- item\n- ", "bullet Enter → yeni maddə")
        check(edited("1. a") { tv in end(tv); tv.insertNewline(nil) } == "1. a\n2. ", "ordered Enter → nömrə artır")
        check(edited("1. a\n2. b\n3. c") { tv in tv.setSelectedRange(NSRange(location: 4, length: 0)); tv.insertNewline(nil) } == "1. a\n2. \n3. b\n4. c", "ortada Enter → sonrakı nömrələr sürüşür")
        check(edited("1. a\n2. b\n3. c\n4. d") { tv in tv.setSelectedRange(NSRange(location: 0, length: 15)); tv.deleteBackward(nil) } == "1. d", "ilk maddələri silmək → nömrələr 1-dən başlayır")
        check(edited("4. DB Viewer Page\n5. Standalone pages\n5. QRMenu Online Order\n8. ") { _ in } == "1. DB Viewer Page\n2. Standalone pages\n3. QRMenu Online Order\n4. ", "yüklənəndə nömrələr düzəlir")
        var caretAfterTyping = -1
        check(edited("1. a\n") { tv in
            end(tv)
            for ch in ["1", "0", ".", " ", "x"] { tv.insertText(ch, replacementRange: tv.selectedRange()) }
            caretAfterTyping = tv.selectedRange().location
        } == "1. a\n2. x" && caretAfterTyping == 9, "\"10. \" yazanda 2-yə düzəlir, kursor yerində qalır")
        check(MarkdownRenderer.renumberingOrderedLists("3. a\n   7. x\n   7. y\n9. b\n\n5. c\n- z\n2. d") == "1. a\n   1. x\n   2. y\n2. b\n\n1. c\n- z\n1. d", "iç-içə siyahılar və boş sətir ayrıca sayılır")
        check(edited("- ") { tv in end(tv); tv.insertNewline(nil) } == "", "boş bulletdə Enter → marker silinir")
        check(edited("[ ] task") { tv in end(tv); tv.insertNewline(nil) } == "[ ] task\n[ ] ", "checkbox Enter → yeni checkbox")
        check(edited("[ ] ") { tv in end(tv); tv.insertNewline(nil) } == "", "boş checkboxda Enter → adi mətnə çevrilir")
        check(edited("word") { tv in tv.setSelectedRange(NSRange(location: 0, length: 4)); tv.wrapSelection(with: "**", placeholder: "x") } == "**word**", "seçimi qalın etmək")
        check(edited("title") { tv in tv.setSelectedRange(NSRange(location: 0, length: 0)); tv.applyHeading(level: 2) } == "## title", "başlıq 2 tətbiqi")
        check(edited("hi") { tv in tv.setSelectedRange(NSRange(location: 0, length: 0)); tv.toggleLinePrefix("> ") } == "> hi", "sitat prefiksi əlavə olundu")

        // Note file create + delete mechanics (used by close → delete).
        let doc = NoteDocument(id: "selftest-\(ProcessInfo.processInfo.globallyUniqueString)")
        doc.save("məzmun")
        check(FileManager.default.fileExists(atPath: doc.fileURL.path), "not faylı yaradıldı")
        doc.delete()
        check(!FileManager.default.fileExists(atPath: doc.fileURL.path), "not faylı silindi")

        print(pass ? "\nSELFTEST PASS" : "\nSELFTEST FAIL")
    }
}
