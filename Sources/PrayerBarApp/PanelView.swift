import SwiftUI
import PrayerCore

/// The menu bar popover.
///
/// Structured around a progress ring and a row of glass chips rather than a list
/// of times, which suits the fact that each prayer is a *window* with a length:
/// Fajr lasts about an hour, Isha until Islamic midnight.
struct PanelView: View {
    static let preferredWidth: CGFloat = 340

    @ObservedObject var state: AppState
    let onOpenSettings: () -> Void

    /// Manually selected prayer, if the user tapped a chip.
    @State private var selection: Prayer?

    private var zone: TimeZone { state.settings.displayTimeZone }

    /// Which prayer the panel is describing: the open window, else the one the
    /// countdown points at, else whatever the user picked.
    private var focus: Prayer? {
        selection ?? state.activeWindow?.prayer ?? state.countdownSubject?.prayer
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            ring
            chipRow
            detailLine
            actionRow
        }
        .padding(16)
        .frame(width: Self.preferredWidth)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayFormatter.string(from: state.now))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                if state.settings.showHijriDate, let hijri = state.today?.hijri {
                    Text(hijri.formatted)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !state.settings.locationName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.system(size: 9))
                    Text(state.settings.locationName).font(.system(size: 11, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    // MARK: - Ring

    private var ring: some View {
        let window = state.activeWindow
        let subject = state.countdownSubject

        let progress: Double? = window.map { open in
            let total = open.duration
            guard total > 0 else { return 0 }
            return max(0, min(1, open.remaining(at: state.now) / total))
        }

        let title: String
        let subtitle: String
        let clock: String
        let symbol: String

        if let window {
            title = window.prayer.displayName
            subtitle = compact(window.remaining(at: state.now)) + " left"
            clock = "ends " + clockString(window.end)
            symbol = window.prayer.symbolName
        } else if let subject {
            title = subject.prayer.displayName
            subtitle = "in " + compact(subject.date.timeIntervalSince(state.now))
            clock = clockString(subject.date)
            symbol = subject.prayer.symbolName
        } else {
            title = "—"
            subtitle = "no times"
            clock = ""
            symbol = "moon.stars"
        }

        return WindowRing(
            progress: progress,
            title: title,
            subtitle: subtitle,
            clock: clock,
            symbol: symbol
        )
        .padding(.vertical, 2)
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 0) {
            ForEach(Prayer.allCases, id: \.self) { prayer in
                chip(for: prayer).frame(maxWidth: .infinity)
            }
        }
    }

    private func chip(for prayer: Prayer) -> some View {
        let time = state.today?.times[prayer]
        let isCurrent = prayer == state.activeWindow?.prayer
        let isFocused = prayer == focus

        return Button {
            selection = (selection == prayer) ? nil : prayer
        } label: {
            VStack(spacing: 5) {
                Image(systemName: prayer.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCurrent ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(.primary))
                    .frame(width: 32, height: 32)
                    .glassEffect(
                        isCurrent
                            ? .regular.tint(Palette.amber.opacity(0.5)).interactive()
                            : .regular.interactive(),
                        in: Circle()
                    )
                Text(time.map(clockString) ?? "--:--")
                    .font(.system(size: 10, weight: isFocused ? .semibold : .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isFocused ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(prayer.displayName): \(windowSummary(for: prayer))")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailLine: some View {
        if let prayer = focus, let window = state.today?.window(for: prayer, nextDay: state.tomorrow) {
            VStack(spacing: 5) {
                Text("\(prayer.displayName) window · \(compact(window.duration))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("\(clockString(window.start))–\(clockString(window.end)) · ends at \(window.endLabel)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                if let necessity = window.necessityEnd {
                    Text("Time of necessity until \(clockString(necessity))")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .multilineTextAlignment(.center)
        } else if let today = state.today {
            Text(today.source.label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                GlassIconButton(systemImage: "gearshape.fill", help: "Settings") {
                    onOpenSettings()
                }
                GlassIconButton(systemImage: "arrow.clockwise", help: "Refresh times") {
                    Task { await state.refresh() }
                }
                if state.settings.locationIsEstimated {
                    GlassIconButton(
                        systemImage: "location.circle.fill",
                        help: "Detect my location",
                        tint: Palette.amber
                    ) {
                        state.detectLocationIfNeeded()
                    }
                }
                Spacer(minLength: 0)
                GlassIconButton(systemImage: "power", help: "Quit PrayerBar", tint: .red) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Formatting

    private func clockString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }

    private func compact(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    private func windowSummary(for prayer: Prayer) -> String {
        guard let window = state.today?.window(for: prayer, nextDay: state.tomorrow) else {
            return "no window recorded"
        }
        return "\(clockString(window.start))–\(clockString(window.end)), ends at \(window.endLabel)"
    }
}
