import SwiftUI
import SajdaCore

/// Pages the popover can show. Kept inline rather than as sheets: a sheet
/// presented from an NSPopover is awkward to dismiss, whereas swapping the
/// content keeps one window and one size.
enum PanelPage {
    case main
    case qibla
    case month
}

/// The menu bar popover.
struct PanelView: View {
    static let preferredWidth: CGFloat = 384

    @ObservedObject var state: AppState
    let onOpenSettings: (SettingsSection) -> Void

    @State private var page: PanelPage = .main
    @Environment(\.colorScheme) private var scheme

    private var zone: TimeZone { state.settings.displayTimeZone }

    var body: some View {
        VStack(spacing: 12) {
            switch page {
            case .main:
                header
                placeAndClock
                nextPrayerBanner
                prayerList
                footer
            case .qibla:
                QiblaView(coordinate: state.settings.coordinate,
                          placeName: state.settings.locationName,
                          heading: state.heading.heading) { page = .main }
            case .month:
                MonthView(state: state) { page = .main }
            }
        }
        .padding(14)
        .frame(width: Self.preferredWidth)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            AppMark(size: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("Sajda Time")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text("Your daily prayer companion")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            // The row of pills that used to sit under the prayer list is gone;
            // these are the same destinations as small header icons.
            HStack(spacing: 2) {
                // Only where a real heading exists, as before.
                if state.heading.isAvailable {
                    iconButton("location.north.circle.fill") { page = .qibla }
                }
                iconButton("calendar") { page = .month }
                iconButton("gearshape.fill") { onOpenSettings(.general) }
                overflowMenu
            }
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.accentText(scheme))
    }

    private var overflowMenu: some View {
        Menu {
            Button("Refresh times") { Task { await state.refresh() } }
            Button("Detect my location") { state.location.detectLocation() }
            Divider()
            Button("Quit Sajda Time") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
        .foregroundStyle(.secondary)
    }

    // MARK: - Place and clock

    private var placeAndClock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium))
                Text(state.settings.locationName.isEmpty ? "Unknown place" : state.settings.locationName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(state.settings.clock(state.now))
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Text(TimeFormatting.longDate(state.now, timeZone: zone))
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(.secondary)
            if state.settings.showHijriDate, let hijri = state.today?.hijri {
                Text(hijri.formatted)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpenSettings(.location) }
    }

    // MARK: - Next prayer banner

    private var nextPrayerBanner: some View {
        let subject = state.countdownSubject
        // Informational, not a control. It used to be a button with a chevron
        // that advanced a highlight through the prayer rows below; the chevron
        // implied navigation it did not do, and the highlight marked a row that
        // was already visible. Which prayer the countdown refers to is a setting
        // (Menubar → countdown target).
        return VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        // Taken from the subject, not from `activeWindow`: the
                        // two can disagree, because which countdown is shown is
                        // a setting. That mismatch is what made the number
                        // impossible to read.
                        Text(subject?.isWindowEnd == true ? "Current Prayer" : "Next Prayer")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(Palette.gold.opacity(0.9))
                        Text(subject?.prayer.displayName ?? "—")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.cream)
                        if let subject {
                            // An hourglass reads "how long is left"; an arrow
                            // reads "how long until". Nine points, so it costs
                            // almost no space.
                            HStack(spacing: 4) {
                                Image(systemName: subject.isWindowEnd ? "hourglass" : "arrow.forward")
                                    .font(.system(size: 9, weight: .bold))
                                Text(state.countdownText(for: subject))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(Palette.gold)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 7)
                .padding(.bottom, 4)

                // The artwork has its own band so it can never sit under the
                // text, and fills the full width so it reads as a background.
                // No artwork strip. At the height this card now needs it showed
                // only the top of the dome, cropped mid-curve, which read as a
                // mistake rather than a design. The gradient below carries it.
            }
            .background(Palette.bannerGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.gold.opacity(0.30), lineWidth: 1)
            )
    }

    /// Step the focus through the day's prayers so each window can be inspected.
    // MARK: - Prayer rows

    private var prayerList: some View {
        VStack(spacing: 6) {
            ForEach(Prayer.allCases, id: \.self) { prayer in
                prayerRow(prayer)
                if prayer == .sunrise, state.settings.showIshraq {
                    ishraqRow()
                }
            }
        }
    }

    /// Ishraq is the voluntary prayer about twenty minutes after sunrise. It is
    /// derived rather than stored, and only shown when asked for.
    @ViewBuilder
    private func ishraqRow() -> some View {
        if let sunrise = state.today?.times[.sunrise] {
            let time = sunrise.addingTimeInterval(20 * 60)
            HStack(spacing: 10) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.amber.opacity(0.75))
                    .frame(width: 22)
                Text("Ishraq")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(state.settings.clock(time))
                    .font(.system(size: 14, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .help("Ishraq: about 20 minutes after sunrise, once the sun has risen clear of the horizon.")
        }
    }

    private func prayerRow(_ prayer: Prayer) -> some View {
        let time = state.today?.times[prayer]
        let window = state.today?.window(for: prayer, nextDay: state.tomorrow)
        let isActive = prayer == state.activeWindow?.prayer
        return HStack(spacing: 10) {
                Image(systemName: prayer.symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isActive ? Palette.emeraldAction : Palette.tint(for: prayer))
                    .frame(width: 22)
                Text(prayer.displayName)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular, design: .rounded))
                Spacer(minLength: 8)
                if isActive, let window {
                    Text(TimeFormatting.countdown(window.remaining(at: state.now)))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accentText(scheme))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.emeraldAction.opacity(0.18)))
                }
                // Both ends of the window, so it is clear how long the prayer
                // remains valid rather than only when it starts.
                VStack(alignment: .trailing, spacing: 0) {
                    Text(rangeText(time: time, window: window))
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular, design: .rounded))
                        .monospacedDigit()
                    if let window {
                        Text("ends at \(window.endLabel)")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Palette.emeraldAction.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .help(windowSummary(for: prayer))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            footerItem(
                symbol: "square.3.layers.3d",
                caption: "Calculation Method",
                value: state.today?.methodName ?? state.settings.method.name
            )
            Divider().frame(height: 32).padding(.horizontal, 12)
            footerItem(
                symbol: "book.closed.fill",
                caption: "Madhab",
                value: state.settings.madhab == .hanafi ? "Hanafi" : "Shafi'i"
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func footerItem(symbol: String, caption: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(caption)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// "5:24 – 6:43 AM", or just the start when the prayer has no window
    /// (sunrise is an instant, not a span).
    private func rangeText(time: Date?, window: PrayerWindow?) -> String {
        guard let time else { return "--:--" }
        guard let window else { return state.settings.clock(time) }
        return TimeFormatting.clockRange(
            window.start, window.end,
            timeZone: zone,
            format: state.settings.clockFormat
        )
    }

    private func windowSummary(for prayer: Prayer) -> String {
        guard let window = state.today?.window(for: prayer, nextDay: state.tomorrow) else {
            return "No window recorded for \(prayer.displayName)."
        }
        let start = state.settings.clock(window.start)
        let end = state.settings.clock(window.end)
        return "\(prayer.displayName) \(start)–\(end), \(TimeFormatting.duration(window.duration)), ends at \(window.endLabel)."
    }
}
