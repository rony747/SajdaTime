import SwiftUI
import AppKit
import SajdaCore

/// Renders the app's own views to PNGs.
///
/// Exists because the interface cannot otherwise be inspected on this machine:
/// screen capture is unavailable, and several layout problems (artwork covering
/// text, glass washing out a card) were only visible by eye. Running the app with
/// `SAJDA_RENDER=<dir>` writes the real views out and exits.
@MainActor
enum PreviewRenderer {

    static func renderAll(state: AppState, to directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        await state.refresh()

        for (label, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            write(
                PanelView(state: state, onOpenSettings: { _ in })
                    .environment(\.colorScheme, scheme),
                to: directory, name: "panel-\(label)"
            )

            // The full-screen reminder for every prayer, since each one uses a
            // different backdrop and the text has to stay legible on all of them.
            for (index, prayer) in Prayer.obligatory.enumerated() {
                write(
                    PrayerAlertView(
                        prayer: prayer,
                        time: state.now,
                        place: state.settings.locationName,
                        hijri: state.today?.hijri?.formatted,
                        settings: state.settings,
                        quote: ReminderQuotes.all[index % ReminderQuotes.all.count],
                        snoozeMinutes: state.settings.snoozeMinutes,
                        onDismiss: {}, onSnooze: {}, onMuteToday: {}
                    )
                    // Laid out at a real screen size; without this the renderer
                    // uses the content's ideal size and the layout overflows.
                    .frame(width: 1680, height: 1050)
                    .environment(\.colorScheme, scheme),
                    to: directory, name: "alert-\(prayer.rawValue)-\(label)"
                )
            }

            // The compass at known headings, so the bezel rotation and the
            // marker placement can be checked against the expected angles.
            for heading in [0.0, 90.0, 180.0, 270.0] {
                write(
                    QiblaView(
                        coordinate: state.settings.coordinate,
                        placeName: state.settings.locationName,
                        heading: heading,
                        onBack: {}
                    )
                    .padding(14)
                    .frame(width: PanelView.preferredWidth)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .environment(\.colorScheme, scheme),
                    to: directory, name: "qibla-\(label)-heading\(Int(heading))"
                )
            }

            for section in SettingsSection.allCases {
                // The real sidebar and detail, minus the ScrollView that cannot
                // be captured offscreen.
                // Without a ScrollView the page is taller than the window, so
                // pin to the top and clip; otherwise the render shows the middle.
                write(
                    SettingsChrome(state: state, section: section, onSelect: { _ in }, scrolls: false)
                        .frame(width: 880, height: 640, alignment: .top)
                        .background(Color(nsColor: .windowBackgroundColor)
                            .opacity(scheme == .dark ? 0.58 : 0.20))
                        .environment(\.colorScheme, scheme)
                        .clipped(),
                    to: directory, name: "settings-\(section.rawValue)-\(label)"
                )
            }
        }
    }

    private static func write<V: View>(_ view: V, to directory: URL, name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            NSLog("Sajda Time: could not render \(name)")
            return
        }
        try? png.write(to: directory.appendingPathComponent("\(name).png"))
        NSLog("Sajda Time: rendered \(name) (\(Int(image.size.width))x\(Int(image.size.height)))")
    }
}
