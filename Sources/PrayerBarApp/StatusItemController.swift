import AppKit
import SwiftUI
import Combine
import PrayerCore

/// Owns the menu bar item.
///
/// This is AppKit rather than SwiftUI's `MenuBarExtra` on purpose. The countdown
/// failing to appear is invisible until someone looks at the screen, and a status
/// item whose title we set ourselves can be logged verbatim and asserted in
/// tests, which a declarative label cannot.
@MainActor
final class StatusItemController: NSObject {

    private let state: AppState
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var debugLogURL: URL?

    init(state: AppState, onOpenSettings: @escaping () -> Void) {
        self.state = state
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let hosting = NSHostingController(rootView: PanelView(state: state, onOpenSettings: onOpenSettings))
        // Without an explicit preferred size the popover is positioned from a
        // stale or zero fitting size on first show, which places it over the menu
        // bar and clips the top of the panel.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: PanelView.preferredWidth, height: 420)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.appearsDisabled = false
        }

        if ProcessInfo.processInfo.environment["PRAYERBAR_DEBUG"] == "1" {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("prayerbar-status.log")
            try? "".write(to: url, atomically: true, encoding: .utf8)
            debugLogURL = url
        }

        // Every published change (the one-second clock tick included) refreshes
        // the item. Deferred by one run loop turn so the value has settled.
        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.update() }
            }
            .store(in: &cancellables)

        update()
    }

    /// Push the current label into the status bar.
    func update() {
        guard let button = statusItem.button else { return }
        let content = state.menuBarContent

        if let symbolName = content.symbolName,
           let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
        } else {
            button.image = nil
        }

        // A leading space separates the text from the icon; without an icon it
        // would just indent the text.
        let separator = button.image == nil ? "" : " "
        button.title = content.text.isEmpty ? "" : separator + content.text
        button.toolTip = state.statusTooltip

        log(MenuBarComposer.description(of: content))
    }

    private func log(_ line: String) {
        guard let debugLogURL else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\(stamp)  \(line)\n"
        guard let data = entry.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: debugLogURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        showPopover()
    }

    /// Show the panel anchored under the status item.
    func showPopover() {
        guard let button = statusItem.button else { return }

        // Lay the SwiftUI content out up front so the popover knows its real
        // height before it decides where to put itself.
        popover.contentViewController?.view.layoutSubtreeIfNeeded()

        // A zero-sized anchor makes AppKit guess; fall back to the item's frame.
        var anchor = button.bounds
        if anchor.width < 1 || anchor.height < 1 {
            anchor = NSRect(x: 0, y: 0, width: max(1, button.frame.width), height: max(1, button.frame.height))
        }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)

        // `minY` asks AppKit to hang the panel below the bar. Verify it actually
        // did, and push it down if the menu bar would cover the top.
        keepBelowStatusItem()

        logGeometry()
    }

    /// Report where the panel ended up relative to the status item it hangs from.
    /// A negative gap means the panel's top is below the item, which is correct.
    private func logGeometry() {
        guard ProcessInfo.processInfo.environment["PRAYERBAR_DEBUG"] == "1",
              let window = popover.contentViewController?.view.window,
              let screen = window.screen ?? NSScreen.main else { return }
        let preferred = popover.contentViewController?.preferredContentSize ?? .zero
        let contentHeight = window.contentRect(forFrameRect: window.frame).height

        // Compare against the status item itself rather than the screen, because
        // `visibleFrame` does not always exclude the menu bar.
        var buttonBottom = "?"
        var gap = "?"
        if let button = statusItem.button, let buttonWindow = button.window {
            let onScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            buttonBottom = String(format: "%.1f", onScreen.minY)
            gap = String(format: "%.1f", window.frame.maxY - onScreen.minY)
        }
        NSLog("PrayerBar: popoverTop=\(String(format: "%.1f", window.frame.maxY)) statusItemBottom=\(buttonBottom) gapAboveStatusItem=\(gap) frame=\(window.frame) preferred=\(preferred) contentHeight=\(contentHeight) clipped=\(preferred.height > contentHeight + 1)")
    }

    /// Make sure the panel hangs below the status item rather than rising into
    /// the menu bar.
    ///
    /// The reference point is the status item itself, not `NSScreen.visibleFrame`:
    /// on a multi-display setup `visibleFrame` does not reliably exclude the menu
    /// bar, which made an earlier version of this guard a no-op.
    private func keepBelowStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let window = popover.contentViewController?.view.window else { return }

        let anchorBottom = buttonWindow
            .convertToScreen(button.convert(button.bounds, to: nil)).minY
        var frame = window.frame
        if frame.maxY > anchorBottom {
            frame.origin.y -= (frame.maxY - anchorBottom)
            window.setFrame(frame, display: true)
        }
    }
}
