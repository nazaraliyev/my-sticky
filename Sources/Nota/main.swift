import AppKit

// Entry point. `.accessory` activation policy => no Dock icon, no app menu bar.
// The app lives as a floating note + a status-bar item.
let app = NSApplication.shared

// Headless self-test path (used for verification, no window).
if CommandLine.arguments.contains("--selftest") {
    SelfTest.run()
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
