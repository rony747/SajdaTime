import AppKit
import SwiftUI
import SajdaCore

/// Covers the screen during prayer time.
///
/// This is a discipline aid, not a lock: Force Quit always works, the overlay
/// can be dismissed with ⌘⎋, and it deliberately does not engage while another
/// application is presenting full screen.
@MainActor
final class FocusModeController: ObservableObject {

    @Published private(set) var isActive = false
    @Published private(set) var activePrayer: Prayer?

    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?
    private var keyMonitor: Any?
    private var lastTriggeredKey: String?

    /// True when the preview is running rather than a real prayer session.
    private var isPreview = false

    // MARK: - Evaluation

    /// Called once per second by `AppState`. Starts a session when a prayer time
    /// passes and the feature is enabled.
    func evaluate(times: PrayerTimes?, settings: AppSettings, now: Date) {
        guard !isPreview else { return }
        guard settings.focusModeEnabled, !isActive, let times else { return }

        for prayer in Prayer.obligatory where settings.focusTrigger.includes(prayer) {
            guard let prayerTime = times.times[prayer] else { continue }
            guard now >= prayerTime else { continue }

            let window = Double(settings.focusDurationMinutes) * 60
            guard now.timeIntervalSince(prayerTime) < window else { continue }

            // One session per prayer per day.
            let key = "\(prayer.rawValue)-\(Int(prayerTime.timeIntervalSince1970))"
            guard key != lastTriggeredKey else { continue }
            lastTriggeredKey = key

            guard !isPresentingFullScreen() else { return }
            activate(prayer: prayer, duration: window)
            return
        }
    }

    /// Heuristic guard: skip when another app owns a window filling the screen,
    /// which is what a call or a presentation looks like.
    private func isPresentingFullScreen() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }

        let screenFrame = NSScreen.main?.frame ?? .zero
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in windows {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == frontmost.processIdentifier,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Allow a small tolerance for menu bar and dock insets.
            if bounds.width >= screenFrame.width - 2 && bounds.height >= screenFrame.height - 2 {
                return true
            }
        }
        return false
    }

    // MARK: - Session control

    func activate(prayer: Prayer, duration: TimeInterval) {
        guard !isActive else { return }
        isActive = true
        activePrayer = prayer
        showOverlay(prayer: prayer, duration: duration)
    }

    /// "Try it for 10 seconds" from Settings.
    func preview(duration: TimeInterval = 10) {
        guard !isActive else { return }
        isPreview = true
        isActive = true
        activePrayer = nil
        showOverlay(prayer: nil, duration: duration)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        isActive = false
        activePrayer = nil
        isPreview = false
    }

    // MARK: - Overlay window

    private func showOverlay(prayer: Prayer?, duration: TimeInterval) {
        let frame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false

        let content = FocusOverlayView(
            prayer: prayer,
            duration: duration,
            onFinish: { [weak self] in self?.dismiss() }
        )
        window.contentView = NSHostingView(rootView: content)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = window

        // Emergency exit.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌘⎋
            if event.keyCode == 53 && event.modifierFlags.contains(.command) {
                self?.dismiss()
                return nil
            }
            return event
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}

/// The full-screen content: a blurred backdrop, the prayer being observed and a
/// live countdown.
private struct FocusOverlayView: View {
    let prayer: Prayer?
    let duration: TimeInterval
    let onFinish: () -> Void

    @State private var remaining: TimeInterval
    @State private var appeared = false

    init(prayer: Prayer?, duration: TimeInterval, onFinish: @escaping () -> Void) {
        self.prayer = prayer
        self.duration = duration
        self.onFinish = onFinish
        _remaining = State(initialValue: duration)
    }

    var body: some View {
        ZStack {
            // A material keeps the underlying desktop perceptible but unusable,
            // which is the point: present, not hidden.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                if let prayer {
                    Image(systemName: prayer.symbolName)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Palette.amber)
                    Text("It's time for \(prayer.displayName)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                } else {
                    Image(systemName: "eye")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Palette.green)
                    Text("Focus Mode preview")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                }

                Text(timeString(remaining))
                    .font(.system(size: 26, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("Press ⌘⎋ to exit early")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
            .padding(48)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.97)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
        .task {
            let deadline = Date().addingTimeInterval(duration)
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                remaining = max(0, left)
                if left <= 0 { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
