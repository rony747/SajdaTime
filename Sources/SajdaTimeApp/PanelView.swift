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
    @State private var selection: Prayer?

    private var zone: TimeZone { state.settings.displayTimeZone }

    var body: some View {
        VStack(spacing: 12) {
            switch page {
            case .main:
                header
                placeAndClock
                nextPrayerBanner
                prayerList
                actionTiles
                footer
            case .qibla:
                QiblaView(coordinate: state.settings.coordinate,
                          placeName: state.settings.locationName) { page = .main }
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
            overflowMenu
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button("Refresh times") { Task { await state.refresh() } }
            Button("Detect my location") { state.location.detectLocation() }
            Divider()
            Button("Settings…") { onOpenSettings(.general) }
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
        return Button {
            cycleSelection()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.activeWindow == nil ? "Next Prayer" : "Current Prayer")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(subject?.prayer.displayName ?? "—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    if let subject {
                        Text(subject.isWindowEnd
                             ? "in " + TimeFormatting.countdown(subject.date.timeIntervalSince(state.now))
                             : "in " + TimeFormatting.countdown(subject.date.timeIntervalSince(state.now)))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.greenDeep)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bannerGradient)
            .overlay(alignment: .bottomTrailing) {
                BannerArt()
                    .frame(height: 92)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            // The banner artwork and its gradient are always light, so the text
            // is pinned to the light scheme; otherwise it turned white in dark
            // mode and vanished into the cream background.
            .environment(\.colorScheme, .light)
        }
        .buttonStyle(.plain)
    }

    /// Step the focus through the day's prayers so each window can be inspected.
    private func cycleSelection() {
        let order = Prayer.allCases
        guard let current = selection ?? state.activeWindow?.prayer ?? state.countdownSubject?.prayer,
              let index = order.firstIndex(of: current) else {
            selection = order.first
            return
        }
        selection = order[(index + 1) % order.count]
    }

    // MARK: - Prayer rows

    private var prayerList: some View {
        VStack(spacing: 6) {
            ForEach(Prayer.allCases, id: \.self) { prayer in
                prayerRow(prayer)
            }
        }
    }

    private func prayerRow(_ prayer: Prayer) -> some View {
        let time = state.today?.times[prayer]
        let window = state.today?.window(for: prayer, nextDay: state.tomorrow)
        let isActive = prayer == state.activeWindow?.prayer
        let isFocused = prayer == (selection ?? state.activeWindow?.prayer ?? state.countdownSubject?.prayer)

        return Button {
            selection = (selection == prayer) ? nil : prayer
        } label: {
            HStack(spacing: 10) {
                Image(systemName: prayer.symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isActive ? Palette.green : Palette.tint(for: prayer))
                    .frame(width: 22)
                Text(prayer.displayName)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular, design: .rounded))
                Spacer(minLength: 8)
                if isActive, let window {
                    Text(TimeFormatting.countdown(window.remaining(at: state.now)))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.greenDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.green.opacity(0.18)))
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
                    .fill(isActive ? Palette.green.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isFocused && !isActive ? Palette.green.opacity(0.45) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(windowSummary(for: prayer))
    }

    // MARK: - Action tiles

    private var actionTiles: some View {
        HStack(spacing: 8) {
            tile("location.north.circle.fill", "Qibla", Palette.green) { page = .qibla }
            tile("calendar", "Calendar", .primary) { page = .month }
            tile("gearshape.fill", "Settings", .primary) { onOpenSettings(.general) }
            tile("bell.fill", "Reminders", Palette.amber) { onOpenSettings(.notifications) }
        }
    }

    private func tile(_ symbol: String, _ title: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            footerItem(
                symbol: "square.3.layers.3d",
                caption: "Calculation Method",
                value: state.today?.methodName ?? state.settings.method.name
            )
            Divider().frame(height: 30)
            footerItem(
                symbol: "book.closed.fill",
                caption: "Madhab",
                value: state.settings.madhab == .hanafi ? "Hanafi" : "Shafi'i"
            )
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
