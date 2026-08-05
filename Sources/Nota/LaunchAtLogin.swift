import ServiceManagement

/// Thin wrapper over SMAppService for the "start at login" toggle.
/// Only works when running from a proper .app bundle (see scripts/make_app.sh).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Nota: launch-at-login failed: \(error.localizedDescription)")
        }
    }
}
