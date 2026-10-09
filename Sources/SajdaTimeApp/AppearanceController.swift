import AppKit
import SajdaCore

/// Applies the appearance preference to the whole app.
///
/// Setting `NSApp.appearance` covers every window, the popover included, so a
/// light/dark override is consistent across all of them.
enum AppearanceController {

    static func apply(_ appearance: AppAppearance) {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
