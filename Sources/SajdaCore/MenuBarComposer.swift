import Foundation

/// What the menu bar item should display.
public struct MenuBarContent: Equatable, Sendable {
    /// SF Symbol name, or nil when the style hides the icon.
    public let symbolName: String?
    /// The text after the icon, e.g. "Fajr 53m".
    public let text: String

    public init(symbolName: String?, text: String) {
        self.symbolName = symbolName
        self.text = text
    }
}

/// Builds the menu bar label.
///
/// Kept as a pure function in the core module for one specific reason: the
/// countdown silently failing to appear is the kind of bug that is invisible
/// until someone looks at the screen, so the composition is testable and is
/// logged verbatim by the status item.
public enum MenuBarComposer {

    /// - Parameter countdownIsRemaining: true when the countdown is time left in
    ///   the current prayer's window, false when it is time until the next prayer
    ///   starts. Without it the number is ambiguous: "Fajr 4h 11m" reads the same
    ///   either way. A word rather than a glyph, because the menu bar is only a
    ///   few characters wide.
    public static func content(
        style: MenuBarLabelStyle,
        prayerName: String,
        prayerSymbol: String,
        countdown: String,
        countdownIsRemaining: Bool = false
    ) -> MenuBarContent {
        var parts: [String] = []
        if style.showsName { parts.append(prayerName) }
        if style.showsCountdown {
            parts.append(countdownIsRemaining ? "\(countdown) left" : "in \(countdown)")
        }

        return MenuBarContent(
            symbolName: style.showsIcon ? prayerSymbol : nil,
            text: parts.joined(separator: " ")
        )
    }

    /// Rendered form used for logging and accessibility, e.g. "Fajr 53m".
    public static func description(of content: MenuBarContent) -> String {
        content.text.isEmpty ? "(icon only)" : content.text
    }
}
