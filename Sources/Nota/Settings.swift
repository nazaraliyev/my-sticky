import AppKit

/// Small typed wrapper over UserDefaults for persisted widget state.
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let noteIDs = "noteIDs"
        static let isFloating = "isFloating"
        static let opacity = "opacity"
        static let fontSize = "fontSize"
        static func frame(_ id: String) -> String { "frame-\(id)" }
    }

    var noteIDs: [String] {
        get { defaults.stringArray(forKey: Key.noteIDs) ?? [] }
        set { defaults.set(newValue, forKey: Key.noteIDs) }
    }

    func frame(forNote id: String) -> NSRect? {
        guard let raw = defaults.string(forKey: Key.frame(id)) else { return nil }
        return NSRectFromString(raw)
    }

    func setFrame(_ frame: NSRect, forNote id: String) {
        defaults.set(NSStringFromRect(frame), forKey: Key.frame(id))
    }

    var isFloating: Bool {
        get { defaults.bool(forKey: Key.isFloating) }
        set { defaults.set(newValue, forKey: Key.isFloating) }
    }

    var fontSize: CGFloat {
        get {
            let value = defaults.double(forKey: Key.fontSize)
            return value == 0 ? 14 : CGFloat(value)
        }
        set { defaults.set(Double(newValue), forKey: Key.fontSize) }
    }

    var opacity: Double {
        get {
            let value = defaults.double(forKey: Key.opacity)
            return value == 0 ? 1.0 : value
        }
        set { defaults.set(newValue, forKey: Key.opacity) }
    }
}
