import AppKit

/// Owns one note window: glass chrome, hover-revealed traffic lights, the "+"
/// (new note) button, the full-height editor, window mode, and persistence.
/// The note has no bottom bar — formatting is live Markdown + keyboard shortcuts.
final class NoteWindowController: NSObject, NSWindowDelegate {
    let document: NoteDocument
    let panel: NotePanel
    let textView: MarkdownTextView

    private let effectView = HoverEffectView()
    private let paperView = PaperView()
    private let scrollView = NSScrollView()
    private let newNoteButton = NSButton()

    private var isFloating = false
    private var saveWorkItem: DispatchWorkItem?

    private let headerInset: CGFloat = 26

    init(document: NoteDocument) {
        self.document = document
        let defaultFrame = NSRect(x: 240, y: 240, width: 360, height: 440)
        let frame = Settings.shared.frame(forNote: document.id) ?? defaultFrame
        panel = NotePanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        textView = MarkdownTextView(frame: NSRect(origin: .zero, size: frame.size))
        super.init()

        configurePanel(frame: frame)
        configureContentView()
        configureTextView(width: frame.width)
        applyMode(floating: Settings.shared.isFloating)
        setChromeVisible(false, animated: false)
        loadNote()
    }

    // MARK: - Setup

    private func configurePanel(frame: NSRect) {
        // Dark note: glass stays dark, text is white, blue markers pop.
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = NSSize(width: 220, height: 180)
        panel.delegate = self
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.setFrame(frame, display: false)
    }

    private func configureContentView() {
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true
        effectView.onHover = { [weak self] hovering in self?.setChromeVisible(hovering, animated: true) }
        panel.contentView = effectView

        paperView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(paperView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        effectView.addSubview(scrollView)

        configureIconButton(newNoteButton, symbol: "plus", fallback: "+", tooltip: "Yeni not")
        newNoteButton.target = self
        newNoteButton.action = #selector(actNewNote)
        effectView.addSubview(newNoteButton)

        NSLayoutConstraint.activate([
            paperView.topAnchor.constraint(equalTo: effectView.topAnchor),
            paperView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            paperView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            paperView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: effectView.topAnchor, constant: headerInset),
            scrollView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -6),
            scrollView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),

            newNoteButton.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -8),
            newNoteButton.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 4),
            newNoteButton.widthAnchor.constraint(equalToConstant: 20),
            newNoteButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    private func configureTextView(width: CGFloat) {
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = MarkdownRenderer.baseFont
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.onModelChange = { [weak self] in self?.scheduleSave() }
        textView.enableLivePreview()
    }

    private func configureIconButton(_ button: NSButton, symbol: String, fallback: String, tooltip: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        button.toolTip = tooltip
        button.contentTintColor = .secondaryLabelColor
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = fallback
            button.imagePosition = .noImage
            button.font = .systemFont(ofSize: 13, weight: .semibold)
        }
    }

    // MARK: - Hover chrome

    private func setChromeVisible(_ visible: Bool, animated: Bool) {
        let alpha: CGFloat = visible ? 1 : 0
        let close = panel.standardWindowButton(.closeButton)
        let mini = panel.standardWindowButton(.miniaturizeButton)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                close?.animator().alphaValue = alpha
                mini?.animator().alphaValue = alpha
            }
        } else {
            close?.alphaValue = alpha
            mini?.alphaValue = alpha
        }
    }

    @objc private func actNewNote() { NoteManager.shared.newNote() }

    // MARK: - Window mode

    func applyMode(floating: Bool) {
        isFloating = floating
        if floating {
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        } else {
            panel.level = .normal
            panel.collectionBehavior = [.moveToActiveSpace]
        }
    }

    // MARK: - Visibility

    func showWindow() { panel.orderFront(nil) }

    func summon() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func cascade(index: Int) {
        guard Settings.shared.frame(forNote: document.id) == nil else { return }
        let offset = CGFloat((index - 1) * 24)
        var frame = panel.frame
        frame.origin.x += offset
        frame.origin.y -= offset
        panel.setFrame(frame, display: false)
    }

    // MARK: - Note IO

    private func loadNote() {
        textView.loadMarkdown(document.load())
    }

    func saveNote() {
        document.save(textView.currentMarkdown())
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNote() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let content = textView.currentMarkdown().trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            // Empty note → delete it entirely (no confirmation).
            DispatchQueue.main.async { NoteManager.shared.delete(self) }
        } else {
            // Has content → just hide it; reopen via menu "Bütün notları göstər".
            saveNote()
            panel.orderOut(nil)
        }
        return false
    }

    func windowDidResize(_ notification: Notification) {
        Settings.shared.setFrame(panel.frame, forNote: document.id)
    }

    func windowDidMove(_ notification: Notification) {
        Settings.shared.setFrame(panel.frame, forNote: document.id)
    }
}
