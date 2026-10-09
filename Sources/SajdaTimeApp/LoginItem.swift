import Foundation
import ServiceManagement

/// Launch-at-login, backed by `SMAppService` (macOS 13+).
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Best effort: registering can fail when the app is not in /Applications or
    /// is running unsigned, and the UI simply reflects the resulting state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Sajda Time: launch-at-login change failed: \(error.localizedDescription)")
            return false
        }
        return true
    }
}
