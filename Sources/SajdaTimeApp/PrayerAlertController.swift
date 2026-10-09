import AppKit
import SwiftUI
import SajdaCore

/// Shows the full-screen reminder over whatever is on screen.
///
/// Kept separate from `FocusModeController`: that one covers the screen for a
/// stretch of time as a discipline aid, whereas this is a notice that wants an
/// answer — dismiss, or snooze for a few minutes.
@MainActor
final class PrayerAlertController: ObservableObject {

    @Published private(set) var isVisible = false

    /// Called when the reminder should come back, with the snooze interval.
    var onSnooze: ((Prayer, TimeInterval) -> Void)?
    var onMuteToday: (() -> Void)?

    private var window: NSWindow?
    private var lastQuoteID: String?
    private var keyMonitor: Any?

    func show(
        prayer: Prayer,
        time: Date,
        settings: AppSettings,
        place: String,
        hijri: String?
    ) {
        guard !isVisible else { return }

        // A different saying each time, never the same one twice in a row.
        let quote = ReminderQuotes.random(excluding: lastQuoteID)
        lastQuoteID = quote.id

        let screenFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false

        let content = PrayerAlertView(
            prayer: prayer,
            time: time,
            place: place,
            hijri: hijri,
            settings: settings,
            quote: quote,
            snoozeMinutes: settings.snoozeMinutes,
            onDismiss: { [weak self] in self?.dismiss() },
            onSnooze: { [weak self] in
                self?.dismiss()
                self?.onSnooze?(prayer, TimeInterval(settings.snoozeMinutes * 60))
            },
            onMuteToday: { [weak self] in
                self?.onMuteToday?()
                self?.dismiss()
            }
        )
        window.contentView = NSHostingView(rootView: content)
        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        isVisible = true

        // Escape always dismisses, whatever the design does.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }

        if ProcessInfo.processInfo.environment["SAJDA_DEBUG"] == "1" {
            NSLog("Sajda Time: reminder shown for \(prayer.displayName), quote=\(quote.id), backdrop=alert-\(prayer.rawValue)")
        }
    }

    func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        isVisible = false
    }
}
