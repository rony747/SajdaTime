import SwiftUI
import PrayerCore

/// The popover shown when the menu bar item is clicked.
struct PanelView: View {
    /// Width the popover is sized to; the panel itself fills it.
    static let preferredWidth: CGFloat = 320

    @ObservedObject var state: AppState
    /// Supplied by the app delegate, which knows how to open settings for an
    /// accessory app whose UI lives in an AppKit popover.
    let onOpenSettings: () -> Void

    private var zone: TimeZone { state.settings.displayTimeZone }

    private var clockFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            nextPrayerBlock
            prayerList
            Divider().padding(.vertical, 6)
            metadata
            Divider().padding(.vertical, 6)
            menuItems
        }
        .padding(12)
        .frame(width: Self.preferredWidth)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dateFormatter.string(from: state.now).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if state.settings.showHijriDate, let hijri = state.today?.hijri {
                Text(hijri.formatted)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var nextPrayerBlock: some View {
        if let subject = state.countdownSubject {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: subject.prayer.symbolName)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(subject.prayer.displayName)
                            .font(.system(size: 20, weight: .semibold))
                        Text(state.countdownText(for: subject))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 8)
                    Text(clockFormatter.string(from: subject.date))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }

                // When a prayer's own window is closing, say what closes it and
                // how long the window actually was — Fajr is about an hour, not
                // the whole morning.
                if let window = subject.window {
                    Text(windowCaption(window))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
        }
    }

    private func windowCaption(_ window: PrayerWindow) -> String {
        let end = clockFormatter.string(from: window.end)
        let duration = Self.durationFormatter.string(from: window.duration) ?? ""
        var caption = "\(window.prayer.displayName) time ends at \(end) (\(window.endLabel)) · window \(duration)"
        if let necessity = window.necessityEnd {
            caption += ". Until \(clockFormatter.string(from: necessity)) is the time of necessity."
        }
        return caption
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    private var prayerList: some View {
        VStack(spacing: 1) {
            ForEach(displayPrayers) { entry in
                prayerRow(entry)
            }
        }
    }

    /// A row in the list. Ishraq is derived rather than stored: it is the
    /// voluntary prayer shortly after sunrise, shown only when asked for.
    private struct PanelRow: Identifiable {
        let id: String
        let prayer: Prayer
        let date: Date
        let label: String
        var isDerived: Bool = false
    }

    private var displayPrayers: [PanelRow] {
        guard let today = state.today else { return [] }
        var rows: [PanelRow] = []
        for entry in today.ordered {
            rows.append(PanelRow(id: entry.prayer.rawValue, prayer: entry.prayer, date: entry.date, label: entry.prayer.displayName))
            if entry.prayer == .sunrise, state.settings.showIshraq {
                rows.append(PanelRow(
                    id: "ishraq",
                    prayer: .sunrise,
                    date: entry.date.addingTimeInterval(20 * 60),
                    label: "Ishraq",
                    isDerived: true
                ))
            }
        }
        return rows
    }

    private func prayerRow(_ entry: PanelRow) -> some View {
        let isHighlighted = entry.prayer == state.highlightedPrayer && !entry.isDerived
        return HStack(spacing: 8) {
            Image(systemName: entry.prayer.symbolName)
                .font(.system(size: 13))
                .foregroundStyle(isHighlighted ? Theme.accentStrong : .secondary)
                .frame(width: 20)
            Text(entry.label)
                .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
                .foregroundStyle(entry.isDerived
                    ? AnyShapeStyle(.secondary)
                    : (isHighlighted ? AnyShapeStyle(Theme.accentStrong) : AnyShapeStyle(.primary)))
            Spacer(minLength: 8)
            if isHighlighted {
                Text(state.compactCountdown)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accentStrong)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent.opacity(0.18)))
                    .monospacedDigit()
            }
            Text(clockFormatter.string(from: entry.date))
                .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
                .foregroundStyle(isHighlighted ? Theme.accentStrong : .primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHighlighted ? Theme.selectedRow : Color.clear)
        )
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let today = state.today {
                metadataRow(
                    icon: "moon.stars",
                    text: "\(today.methodName) (\(state.settings.madhab == .hanafi ? "Hanafi" : "Standard"))"
                )
                metadataRow(
                    icon: "location",
                    text: String(format: "%.4f, %.4f · %@", state.settings.latitude, state.settings.longitude, zone.identifier)
                )
                metadataRow(icon: "antenna.radiowaves.left.and.right", text: today.source.label)
                if state.settings.locationIsEstimated {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 10))
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location estimated from your timezone.")
                            Button("Detect my location") { state.detectLocationIfNeeded() }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                if today.usedPolarFallback {
                    metadataRow(icon: "exclamationmark.triangle", text: "No sunrise/sunset here — mid-latitude reference used")
                }
            } else {
                metadataRow(icon: "hourglass", text: "Loading times…")
            }
        }
        .padding(.horizontal, 4)
    }

    private func metadataRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
    }

    private var menuItems: some View {
        VStack(spacing: 1) {
            PanelButton(title: "Settings…", systemImage: "gearshape") {
                onOpenSettings()
            }
            PanelButton(title: "Refresh Times", systemImage: "arrow.clockwise") {
                Task { await state.refresh() }
            }
            PanelButton(title: "Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

/// A full-width menu row with a hover highlight.
private struct PanelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Theme.control : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
