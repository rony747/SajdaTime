import AppKit
import SwiftUI

/// The settings window, built and shown explicitly.
///
/// The window is translucent and backed by `NSGlassEffectView`. Without that,
/// the cards inside had nothing to refract: they sat on an opaque
/// `windowBackgroundColor` and rendered as flat rectangles, which is exactly why
/// the settings window did not look like Liquid Glass while the popover did.
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, let window = self.window else { return }
            if !window.isKeyWindow { window.makeKey() }
            if ProcessInfo.processInfo.environment["PRAYERBAR_DEBUG"] == "1" {
                NSLog("PrayerBar: settings window — visible=\(window.isVisible) key=\(window.isKeyWindow) opaque=\(window.isOpaque) glass=\(self.window?.contentView is NSGlassEffectView) frame=\(window.frame)")
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PrayerBar Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Translucency is what lets the glass have something to work with.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.hasShadow = true

        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = 0
        glass.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: SettingsView(state: state))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView = hosting
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: glass.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
        ])

        window.contentView = glass
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // Back to menu-bar-only: no Dock icon once settings are closed.
        NSApp.setActivationPolicy(.accessory)
    }
}
