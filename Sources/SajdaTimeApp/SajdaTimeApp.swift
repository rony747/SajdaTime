import AppKit
import Combine
import UserNotifications
import SajdaCore

/// SajdaTime — a menu bar app.
///
/// Deliberately a plain AppKit application rather than a SwiftUI `App`. SwiftUI's
/// scene machinery proved unreliable for this shape of app twice over: a
/// `MenuBarExtra` label that would not render its countdown, and a `Settings`
/// scene that would not open for an accessory (LSUIElement) app. Both the status
/// item and the settings window are now created and shown explicitly, and SwiftUI
/// is used only for view content, hosted in AppKit containers.
@main
enum SajdaTimeMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    let state = AppState()
    private var statusItem: StatusItemController?
    private var cancellables: Set<AnyCancellable> = []
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show notifications even when the app is frontmost, otherwise the
        // sample button appears to do nothing while the Settings window is open.
        UNUserNotificationCenter.current().delegate = self

        NSApp.setActivationPolicy(.accessory)

        statusItem = StatusItemController(state: state) { [weak self] section in
            self?.openSettings(section: section)
        }

        // The appearance preference applies to every window, the popover
        // included, so it is set on the application rather than per view.
        state.connectPrayerAlert()
        AppearanceController.apply(state.settings.appearance)
        state.$settings
            .map(\.appearance)
            .removeDuplicates()
            .sink { [weak self] appearance in
                AppearanceController.apply(appearance)
                // The popover does not inherit this from NSApp, so it is set too.
                self?.statusItem?.applyAppearance(appearance)
            }
            .store(in: &cancellables)

        // Offscreen render mode, used to inspect the interface without a screen.
        if let directory = ProcessInfo.processInfo.environment["SAJDA_RENDER"] {
            Task { @MainActor in
                await PreviewRenderer.renderAll(state: state, to: URL(fileURLWithPath: directory))
                NSApp.terminate(nil)
            }
            return
        }

        // Development aid: cycle the appearance after launch so the live update
        // path can be observed without driving the UI by hand.
        if ProcessInfo.processInfo.environment["SAJDA_CYCLE_APPEARANCE"] == "1" {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                state.settings.appearance = .dark
                try? await Task.sleep(for: .seconds(3))
                state.settings.appearance = .light
            }
        }

        // Development aid: show the reminder for a named prayer immediately.
        if let raw = ProcessInfo.processInfo.environment["SAJDA_TEST_ALERT"],
           let prayer = Prayer(rawValue: raw) {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                self.state.previewAlert(for: prayer)
            }
        }

        if ProcessInfo.processInfo.environment["SAJDA_OPEN_SETTINGS"] == "1" {
            openSettings()
        }
        if ProcessInfo.processInfo.environment["SAJDA_OPEN_POPOVER"] == "1" {
            // Deferred so the status item has been laid out by the bar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.statusItem?.showPopover()
            }
        }
    }

    /// Reopening an already-running menu bar app has nowhere obvious to go.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openSettings() }
        return true
    }

    /// Show the settings window, optionally jumping to a section.
    ///
    /// This is the only path — there is no SwiftUI `Settings` scene involved, so
    /// if this runs, the window appears.
    func openSettings(section: SettingsSection = .general) {
        state.requestedSettingsSection = section
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(state: state)
        }
        settingsWindow?.show()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
