import AppKit
import SwiftUI
import SajdaCore

/// Shows the full-screen reminder over whatever is on screen.
///
/// Kept separate from `FocusModeController`: that one covers the screen for a
/// stretch of time as a discipline aid, whereas this is a notice that wants an
/// answer — dismiss, or snooze for a few minutes.
/// A borderless `NSWindow` returns `canBecomeKey == false` by default, so the
/// reminder could never take key focus — which left Escape and Return dead.
/// Overriding it is what makes the window able to receive them.
final class AlertWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PrayerAlertController: ObservableObject {

    @Published private(set) var isVisible = false

    /// Called when the reminder should come back, with the snooze interval.
    var onSnooze: ((Prayer, TimeInterval) -> Void)?
    var onMuteToday: (() -> Void)?

    /// One window per display. A single window spanning the union of all screens
    /// centred the content across them, which put it low on whichever screen the
    /// person was actually looking at and zoomed the backdrop oddly.
    private var windows: [NSWindow] = []
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
        // One window per screen, each composed for its own aspect ratio.
        for screen in NSScreen.screens {
            let window = AlertWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.contentView = NSHostingView(rootView: content)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }

        // Activate first, then take key: the reminder has to accept Escape and
        // Return, and it cannot do that while it is not the key window.
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        windows.first?.makeFirstResponder(windows.first?.contentView)
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
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                let key = self.windows.first?.isKeyWindow ?? false
                let active = NSApp.isActive
                NSLog("Sajda Time: reminder shown for \(prayer.displayName), quote=\(quote.id), backdrop=alert-\(prayer.rawValue), key=\(key), appActive=\(active)")
            }
        }
    }

    func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in windows { window.orderOut(nil) }
        windows = []
        isVisible = false
    }
}
