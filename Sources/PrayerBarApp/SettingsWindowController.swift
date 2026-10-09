import AppKit
import SwiftUI

/// The settings window, built and shown explicitly.
///
/// Previously this was SwiftUI's `Settings` scene, opened through the
/// `showSettingsWindow:` responder action. For an accessory app whose only scene
/// was `Settings`, that action resolved without a window ever appearing, so the
/// window is now owned here instead.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
        super.init()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            window = makeWindow()
        }
        guard let window else { return }

        // A pure accessory app is refused key-window status, which leaves the
        // window visible but unable to take clicks or keystrokes. Promoting to
        // `.regular` while settings are open is the standard remedy; the policy
        // is restored to `.accessory` when the window closes.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Activation is asynchronous, so confirm focus once it has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, let window = self.window else { return }
            if !window.isKeyWindow {
                window.makeKey()
            }
            if ProcessInfo.processInfo.environment["PRAYERBAR_DEBUG"] == "1" {
                NSLog("PrayerBar: settings window — visible=\(window.isVisible) key=\(window.isKeyWindow) frame=\(window.frame) policy=\(NSApp.activationPolicy().rawValue)")
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(state: state))
        let window = NSWindow(contentViewController: hosting)
        window.title = "PrayerBar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // Back to menu-bar-only: no Dock icon once settings are closed.
        NSApp.setActivationPolicy(.accessory)
    }
}
