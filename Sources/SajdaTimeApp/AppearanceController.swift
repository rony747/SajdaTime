import AppKit
import SajdaCore

/// Applies the appearance preference to the whole app.
///
/// Setting `NSApp.appearance` covers every window, the popover included, so a
/// light/dark override is consistent across all of them.
enum AppearanceController {

    /// The matching `NSAppearance`, or nil to follow the system.
    static func nsAppearance(for appearance: AppAppearance) -> NSAppearance? {
        switch appearance {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static func apply(_ appearance: AppAppearance) {
        NSApp.appearance = nsAppearance(for: appearance)
    }
}
