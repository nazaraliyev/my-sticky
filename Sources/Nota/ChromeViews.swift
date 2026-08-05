import AppKit

/// Glass background that reports pointer enter/exit so the controller can
/// fade the window controls in and out on hover.
final class HoverEffectView: NSVisualEffectView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

/// A semi-opaque "paper" layer that lightens the glass for readable text.
/// Drawn each pass so it adapts to light/dark appearance.
final class PaperView: NSView {
    var fillAlpha: CGFloat = 0.45

    override var allowsVibrancy: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.withAlphaComponent(fillAlpha).setFill()
        dirtyRect.fill()
    }
}
