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
            if ProcessInfo.processInfo.environment["SAJDA_DEBUG"] == "1" {
                // The band the user saw was the gap between the hosting view and
                // the window, so log both rather than the frame alone.
                let content = window.contentView?.bounds ?? .zero
                let host = (window.contentView?.subviews.first)?.frame ?? .zero
                NSLog("Sajda Time: settings window — visible=\(window.isVisible) key=\(window.isKeyWindow) opaque=\(window.isOpaque) backdrop=\(self.window?.contentView is NSVisualEffectView) appearance=\(NSApp.appearance?.name.rawValue ?? "system") frame=\(window.frame) content=\(content.size) host=\(host.size)")
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
        window.title = "Sajda Time Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Translucency is what lets the glass have something to work with.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.hasShadow = true

        // A standard translucent window, not a glass one. Glass is reserved for
        // the interactive surfaces that float above this, which is how the
        // design system intends it to be layered.
        let backdrop = NSVisualEffectView()
        backdrop.material = .underWindowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .followsWindowActiveState
        backdrop.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: SettingsView(state: state))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: backdrop.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor),
        ])

        window.contentView = backdrop
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        // Back to menu-bar-only: no Dock icon once settings are closed.
        NSApp.setActivationPolicy(.accessory)
    }
}
