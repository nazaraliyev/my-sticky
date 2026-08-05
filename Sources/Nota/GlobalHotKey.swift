import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey (default ⌥⌘N) to summon/focus the note from
/// anywhere. Uses Carbon's RegisterEventHotKey, which — unlike NSEvent global
/// monitors — needs no Accessibility permission.
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    private var hotKeyRef: EventHotKeyRef?
    private var onFire: (() -> Void)?

    private init() {}

    /// Registers ⌥⌘N. Safe to call once at launch.
    func register(onFire: @escaping () -> Void) {
        self.onFire = onFire

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let this = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                this.onFire?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E4F5441), id: 1) // 'NOTA'
        let modifiers = UInt32(cmdKey | optionKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
