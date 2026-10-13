import SwiftUI
import UniformTypeIdentifiers
import SajdaCore

// MARK: - General
struct GeneralSection: View {
    @ObservedObject var state: AppState
    let goTo: (SettingsSection) -> Void

    var body: some View {
        SummaryCard(state: state, goTo: goTo)

        // These cards summarise and link. The controls live in one place each —
        // having the same value editable in two sections made it unclear which
        // was authoritative, and they could disagree on screen at the same time.
        SettingsCard(title: "Location", symbol: "mappin.circle.fill") {
            CardRow(
                "Place",
                subtitle: state.settings.locationIsEstimated
                    ? "Estimated from your timezone until a fix arrives"
                    : "Detected"
            ) {
                HStack(spacing: 8) {
                    Text(state.settings.locationName.isEmpty ? "Unknown" : state.settings.locationName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    CardButton(title: "Change…") { goTo(.location) }
                }
            }
        }

        SettingsCard(title: "Prayer Times", symbol: "clock.fill") {
            CardRow("Calculation method") {
                Text(state.settings.method.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            CardRow("Madhab (Asr)") {
                HStack(spacing: 8) {
                    Text(state.settings.madhab == .hanafi ? "Hanafi" : "Shafi'i")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    CardButton(title: "Change…") { goTo(.prayerTimes) }
                }
            }
        }

        SettingsCard(title: "Notifications", symbol: "bell.fill") {
            CardRow("Prayer time notifications") {
                HStack(spacing: 8) {
                    Text(state.settings.notificationsEnabled ? "On" : "Off")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    CardButton(title: "Manage…") { goTo(.notifications) }
                }
            }
        }

        SettingsCard(title: "Startup", symbol: "power") {
            CardRow("Launch at login", subtitle: "Start Sajda Time automatically when you log in to your Mac.") {
                SettingToggle(isOn: state.binding(\.launchAtLogin))
            }
        }
    }
}
/// The banner at the top of General: place, date and the next prayer.
struct SummaryCard: View {
    @ObservedObject var state: AppState
    let goTo: (SettingsSection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 13, weight: .medium))
                        Text(state.settings.locationName.isEmpty ? "Unknown place" : state.settings.locationName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.cream)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Palette.gold.opacity(0.8))
                    }
                    Text(TimeFormatting.longDate(state.now, timeZone: state.settings.displayTimeZone))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.cream.opacity(0.72))
                    if state.settings.showHijriDate, let hijri = state.today?.hijri {
                        Text(hijri.formatted)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.cream.opacity(0.72))
                    }
                }
                Spacer(minLength: 0)

                if let subject = state.countdownSubject {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(subject.isWindowEnd ? "Current Prayer" : "Next Prayer")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(Palette.gold.opacity(0.9))
                        Text(subject.prayer.displayName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.cream)
                        HStack(spacing: 4) {
                            Image(systemName: subject.isWindowEnd ? "hourglass" : "arrow.forward")
                                .font(.system(size: 9, weight: .bold))
                            Text(state.countdownText(for: subject))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Palette.gold)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 12)
            .padding(.bottom, 9)

            // Full-width band. Kept here, unlike the panel's card, because this
            // one is twice as wide and has room for the illustration to read; 48
            // still shows the mosque and the hills rather than a slice of sky.
            BannerArt()
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .clipped()
        }
        .background(Palette.bannerGradient)
        .clipShape(RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous)
                .strokeBorder(Palette.gold.opacity(0.30), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { goTo(.prayerTimes) }
    }
}
// MARK: - Prayer Times

struct PrayerTimesSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        SettingsCard(title: "Source", symbol: "antenna.radiowaves.left.and.right") {
            CardRow("Time source") {
                SettingSegmented(
                    options: TimeSourceMode.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.timeSourceMode)
                )
                .frame(width: 240)
            }
            if state.settings.timeSourceMode == .manual {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    CardRow(prayer.displayName) {
                        TextField("HH:mm", text: manualTimeBinding(prayer))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 82)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            CardRow("Fetch times from Aladhan", subtitle: "Falls back to on-device calculation when offline.") {
                SettingToggle(isOn: state.binding(\.fetchLiveTimes))
            }
            CardRow("Showing") {
                Text(state.today?.source.label ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }

        SettingsCard(title: "Method", symbol: "function") {
            CardRow("Calculation Method") {
                SettingPicker(
                    options: CalculationMethod.all.map { ($0.id, $0.name) },
                    selection: state.binding(\.methodID),
                    width: 260
                )
            }
            CardRow("Madhab (Asr)") {
                SettingSegmented(
                    options: [(Madhab.standard, "Shafi'i"), (Madhab.hanafi, "Hanafi")],
                    selection: state.binding(\.madhab)
                )
                .frame(width: 240)
            }
            CardRow("High latitude") {
                SettingPicker(
                    options: HighLatitudeRule.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.highLatitudeRule),
                    width: 240
                )
            }
            CardRow("Auto-detect method") {
                SettingToggle(isOn: state.binding(\.autoDetectMethod))
            }
        }

        SettingsCard(title: "Prayer windows", symbol: "hourglass") {
            CardRow("Each prayer's valid time, and what ends it") { EmptyView() }
            ForEach(Prayer.allCases, id: \.self) { prayer in
                CardRow(prayer.displayName) {
                    if let window = state.today?.window(for: prayer, nextDay: state.tomorrow) {
                        HStack(spacing: 8) {
                            Text(TimeFormatting.clockRange(
                                window.start, window.end,
                                timeZone: state.settings.displayTimeZone,
                                format: state.settings.clockFormat
                            ))
                            .font(.system(size: 12, design: .rounded))
                            .monospacedDigit()
                            Text(TimeFormatting.duration(window.duration))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 62, alignment: .trailing)
                            Text("ends at \(window.endLabel)")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .frame(width: 130, alignment: .leading)
                        }
                    } else {
                        Text("an instant, not a span")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }

        SettingsCard(title: "Fine tuning", symbol: "slider.horizontal.3") {
            CardRow("Minutes added to each calculated time") { EmptyView() }
            ForEach(Prayer.allCases, id: \.self) { prayer in
                CardRow(prayer.displayName) {
                    Stepper(
                        "\(Int(state.settings.userAdjustments[prayer.rawValue] ?? 0)) min",
                        value: adjustmentBinding(prayer),
                        in: -60...60
                    )
                    .frame(width: 120)
                }
            }
        }
    }

    private func manualTimeBinding(_ prayer: Prayer) -> Binding<String> {
        Binding(
            get: { state.settings.manualTimes[prayer.rawValue] ?? "" },
            set: { state.settings.manualTimes[prayer.rawValue] = $0 }
        )
    }

    private func adjustmentBinding(_ prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { Int(state.settings.userAdjustments[prayer.rawValue] ?? 0) },
            set: { value in
                if value == 0 {
                    state.settings.userAdjustments.removeValue(forKey: prayer.rawValue)
                } else {
                    state.settings.userAdjustments[prayer.rawValue] = Double(value)
                }
            }
        )
    }
}

// MARK: - Notifications

struct NotificationsSection: View {
    @ObservedObject var state: AppState
    @State private var previewPrayer: Prayer = .asr

    var body: some View {
        SettingsCard(title: "Alerts", symbol: "bell.fill") {
            CardRow("Enable prayer time notifications") {
                SettingToggle(isOn: state.binding(\.notificationsEnabled))
            }
            CardRow("Reminder timing", subtitle: "Applied to every prayer unless overridden below.") {
                SettingPicker(
                    options: [(0, "Off"), (5, "5 min before"), (10, "10 min before"),
                              (15, "15 min before"), (20, "20 min before"), (30, "30 min before")],
                    selection: state.optionalIntBinding(\.defaultEarlyReminderMinutes),
                    width: 170
                )
            }
            CardRow("Iqamah offset") {
                SettingPicker(
                    options: [(0, "Off"), (5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min")],
                    selection: state.optionalIntBinding(\.defaultIqamahMinutes),
                    width: 140
                )
            }
            CardRow("Show a full-screen reminder", subtitle: "Covers the screen when a prayer begins, with a short hadith and a backdrop for that prayer.") {
                SettingToggle(isOn: state.binding(\.fullScreenReminder))
            }
            CardRow("Close the reminder automatically", subtitle: "It counts down and then closes itself; Dismiss and Escape always work too.") {
                SettingPicker(
                    options: [(0, "Never"), (5, "5 min"), (10, "10 min"), (15, "15 min"), (30, "30 min")],
                    selection: state.binding(\.alertAutoCloseMinutes),
                    width: 120
                )
            }
            CardRow("Snooze length") {
                SettingPicker(
                    options: [(5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min")],
                    selection: state.binding(\.snoozeMinutes),
                    width: 120
                )
            }
            CardRow("Default sound", subtitle: "Used for every reminder unless a prayer overrides it.") {
                HStack(spacing: 8) {
                    SettingPicker(
                        options: NotificationService.availableSounds.map { ($0, $0) },
                        selection: state.binding(\.defaultSoundName),
                        width: 170
                    )
                    CardButton(title: "Play", systemImage: "play.fill") {
                        state.notifications.playSound(named: state.settings.defaultSoundName)
                    }
                }
            }
            CardRow("Adhan at prayer time", subtitle: "Plays an audio file you choose; notifications otherwise use the sound above.") {
                SettingToggle(isOn: state.binding(\.playFullAdhan))
            }
            if state.settings.playFullAdhan {
                CardRow("Audio file") {
                    HStack(spacing: 8) {
                        Text(state.settings.adhanAudioPath.map { ($0 as NSString).lastPathComponent } ?? "none chosen")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        CardButton(title: "Choose…") { chooseAdhanFile() }
                    }
                }
            }
            HStack(spacing: 10) {
                CardButton(title: "Send a sample notification", systemImage: "bell.badge") {
                    Task { await state.notifications.sendSample() }
                }
                Spacer()
            }
            CardRow("Test the full-screen reminder", subtitle: "Shows it straight away, with that prayer's backdrop.") {
                HStack(spacing: 8) {
                    SettingPicker(
                        options: Prayer.obligatory.map { ($0, $0.displayName) },
                        selection: $previewPrayer,
                        width: 130
                    )
                    CardButton(title: "Preview", systemImage: "play.rectangle.fill") {
                        state.previewAlert(for: previewPrayer)
                    }
                }
            }
            if let error = state.notifications.lastError {
                StatusLine(text: error, kind: .error)
            }
            if state.notifications.authorizationStatus == .denied {
                StatusLine(text: "Reminders are blocked in System Settings › Notifications.", kind: .error)
            }
        }

        SettingsCard(title: "Per prayer", symbol: "list.bullet") {
            ForEach(Prayer.obligatory, id: \.self) { prayer in
                PrayerReminderRow(state: state, prayer: prayer)
            }
        }
    }

    private func chooseAdhanFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose the audio file to play at prayer time."
        if panel.runModal() == .OK, let url = panel.url {
            state.settings.adhanAudioPath = url.path
        }
    }
}

/// One prayer's reminder settings, expanding to its own timings.
struct PrayerReminderRow: View {
    @ObservedObject var state: AppState
    let prayer: Prayer
    @State private var expanded = false

    var body: some View {
        let reminder = state.settings.reminder(for: prayer)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: prayer.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.tint(for: prayer))
                    .frame(width: 20)
                Text(prayer.displayName)
                    .font(.system(size: 12.5))
                Spacer(minLength: 8)
                Text(reminder.mode == .off ? "off" : reminder.mode.displayName.lowercased())
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                SettingToggle(isOn: Binding(
                    get: { reminder.mode != .off },
                    set: { on in state.reminderModeBinding(prayer).wrappedValue = on ? .automatic : .off }
                ))
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    CardRow("Timing") {
                        SettingSegmented(
                            options: ReminderMode.allCases.map { ($0, $0.displayName) },
                            selection: state.reminderModeBinding(prayer)
                        )
                        .frame(width: 210)
                    }

                    if reminder.mode == .manual {
                        ForEach(Array(reminder.offsets.enumerated()), id: \.offset) { index, offset in
                            HStack(spacing: 8) {
                                SettingPicker(
                                    options: ReminderOffset.Anchor.allCases.map { ($0, $0.displayName) },
                                    selection: offsetAnchorBinding(index),
                                    width: 100
                                )
                                Stepper("\(offset.minutes) min", value: offsetMinutesBinding(index), in: 0...120, step: 5)
                                    .frame(width: 120)
                                Button {
                                    var updated = reminder
                                    guard index < updated.offsets.count else { return }
                                    updated.offsets.remove(at: index)
                                    state.settings.perPrayer[prayer.rawValue] = updated
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .disabled(reminder.offsets.count <= 1)
                                Spacer()
                            }
                        }
                        HStack {
                            CardButton(title: "Add a reminder", systemImage: "plus") {
                                var updated = reminder
                                updated.mode = .manual
                                updated.offsets.append(ReminderOffset(anchor: .before, minutes: 10))
                                state.settings.perPrayer[prayer.rawValue] = updated
                            }
                            Spacer()
                        }
                    }

                    CardRow("Adhan") {
                        SettingToggle(isOn: state.reminderBinding(prayer, \.playAdhan))
                    }
                    CardRow("Sound") {
                        SettingPicker(
                            options: [("", "App default")] + NotificationService.availableSounds.map { ($0, $0) },
                            selection: Binding(
                                get: { reminder.soundName ?? "" },
                                set: { value in
                                    var updated = reminder
                                    updated.soundName = value.isEmpty ? nil : value
                                    state.settings.perPrayer[prayer.rawValue] = updated
                                }
                            ),
                            width: 170
                        )
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 6)
    }

    private func offsetAnchorBinding(_ index: Int) -> Binding<ReminderOffset.Anchor> {
        Binding(
            get: {
                let offsets = state.settings.reminder(for: prayer).offsets
                return index < offsets.count ? offsets[index].anchor : .at
            },
            set: { value in
                var reminder = state.settings.reminder(for: prayer)
                guard index < reminder.offsets.count else { return }
                reminder.offsets[index].anchor = value
                state.settings.perPrayer[prayer.rawValue] = reminder
            }
        )
    }

    private func offsetMinutesBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: {
                let offsets = state.settings.reminder(for: prayer).offsets
                return index < offsets.count ? offsets[index].minutes : 0
            },
            set: { value in
                var reminder = state.settings.reminder(for: prayer)
                guard index < reminder.offsets.count else { return }
                reminder.offsets[index].minutes = value
                state.settings.perPrayer[prayer.rawValue] = reminder
            }
        )
    }
}

// MARK: - Location

struct LocationSection: View {
    @ObservedObject var state: AppState

    private static let zones = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        SettingsCard(title: "Position", symbol: "mappin.circle.fill") {
            CardRow("Mode") {
                SettingSegmented(
                    options: LocationMode.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.locationMode)
                )
                .frame(width: 210)
            }
            HStack {
                CardButton(
                    title: state.location.isLocating ? "Locating…" : "Detect my location",
                    systemImage: "location.fill"
                ) {
                    state.location.detectLocation()
                }
                .disabled(state.location.isLocating)
                Spacer()
            }
            CardRow("Latitude") { coordinateField(state.userCoordinateBinding(\.latitude)) }
            CardRow("Longitude") { coordinateField(state.userCoordinateBinding(\.longitude)) }
            CardRow("Elevation") {
                HStack(spacing: 6) {
                    TextField("", value: state.binding(\.elevation), format: .number.precision(.fractionLength(0...1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("m").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            if state.settings.locationIsEstimated {
                StatusLine(text: "Position estimated from your timezone until a real fix arrives.", kind: .info)
            }
            if let message = state.location.errorMessage {
                StatusLine(text: message, kind: .warning)
            }
        }

        SettingsCard(title: "Timezone", symbol: "globe") {
            CardRow("Show times on") {
                SettingSegmented(
                    options: TimeZoneMode.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.timeZoneMode)
                )
                .frame(width: 240)
            }
            if state.settings.timeZoneMode == .explicit {
                CardRow("Zone") {
                    SettingPicker(
                        options: Self.zones.map { ($0, $0) },
                        selection: state.binding(\.explicitTimeZoneID),
                        width: 260
                    )
                }
            }
        }

        SettingsCard(title: "Hijri date", symbol: "moon.stars.fill") {
            CardRow("Day adjustment", subtitle: "Shift for local moon sighting.") {
                Stepper("\(state.settings.hijriDayAdjustment) days",
                        value: state.binding(\.hijriDayAdjustment), in: -3...3)
                    .frame(width: 130)
            }
            CardRow("Today") {
                Text(state.today?.hijri?.formatted ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func coordinateField(_ binding: Binding<Double>) -> some View {
        TextField("", value: binding, format: .number.precision(.fractionLength(0...6)))
            .textFieldStyle(.roundedBorder)
            .frame(width: 130)
            .multilineTextAlignment(.trailing)
    }
}

// MARK: - Appearance

struct AppearanceSection: View {
    @ObservedObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        SettingsCard(title: "Appearance", symbol: "circle.lefthalf.filled") {
            CardRow("Theme", subtitle: "Applies to the panel and the settings window.") {
                SettingSegmented(
                    options: AppAppearance.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.appearance)
                )
                .frame(width: 240)
            }
            CardRow("") {
                HStack(spacing: 14) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        HStack(spacing: 5) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 11))
                            Text(option.displayName)
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundStyle(state.settings.appearance == option
                                         ? Palette.accentText(scheme) : Color.secondary)
                    }
                    Spacer()
                }
            }
        }

        SettingsCard(title: "Clock", symbol: "clock.fill") {
            CardRow("Time format", subtitle: "Applies to the panel, the menu bar and all times shown here.") {
                SettingSegmented(
                    options: [(ClockFormat.twelveHour, "12-hour"), (ClockFormat.twentyFourHour, "24-hour")],
                    selection: state.binding(\.clockFormat)
                )
                .frame(width: 200)
            }
            CardRow("Preview") {
                HStack(spacing: 10) {
                    Text(ClockFormat.twelveHour.example)
                        .font(.system(size: 13, weight: state.settings.clockFormat == .twelveHour ? .semibold : .regular,
                                      design: .rounded))
                        .foregroundStyle(state.settings.clockFormat == .twelveHour ? Palette.greenInk : .secondary)
                        .monospacedDigit()
                    Text(ClockFormat.twentyFourHour.example)
                        .font(.system(size: 13, weight: state.settings.clockFormat == .twentyFourHour ? .semibold : .regular,
                                      design: .rounded))
                        .foregroundStyle(state.settings.clockFormat == .twentyFourHour ? Palette.greenInk : .secondary)
                        .monospacedDigit()
                }
            }
        }

        SettingsCard(title: "Panel", symbol: "rectangle.on.rectangle") {
            CardRow("Show Ishraq time", subtitle: "Adds the voluntary prayer shortly after sunrise.") {
                SettingToggle(isOn: state.binding(\.showIshraq))
            }
            CardRow("Show Hijri date") {
                SettingToggle(isOn: state.binding(\.showHijriDate))
            }
        }
    }
}

// MARK: - Menubar

struct MenubarSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        SettingsCard(title: "Menu bar item", symbol: "menubar.rectangle") {
            CardRow("Shows") {
                SettingPicker(
                    options: MenuBarLabelStyle.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.menuBarLabelStyle),
                    width: 230
                )
            }
            CardRow("Counts down") {
                SettingPicker(
                    options: CountdownTarget.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.countdownTarget),
                    width: 230
                )
            }
            CardRow("Preview") {
                HStack(spacing: 5) {
                    if state.settings.menuBarLabelStyle.showsIcon {
                        Image(systemName: state.countdownSubject?.prayer.symbolName ?? "moon.stars")
                    }
                    if state.settings.menuBarLabelStyle.showsName {
                        Text(state.countdownSubject?.prayer.displayName ?? "—")
                    }
                    if state.settings.menuBarLabelStyle.showsCountdown {
                        Text(state.compactCountdown).monospacedDigit()
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            }
        }

        SettingsCard(title: "Stored data", symbol: "internaldrive") {
            CardRow("Cached days") {
                HStack(spacing: 8) {
                    Text(CacheInfo.describe()).font(.system(size: 12)).foregroundStyle(.secondary)
                    CardButton(title: "Clear") { state.clearCachedTimes() }
                }
            }
        }
    }
}

enum CacheInfo {
    static func describe() -> String {
        let directory = PrayerTimesCache.defaultDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let days = contents.filter { $0.pathExtension == "json" }.count
        return days == 1 ? "1 day" : "\(days) days"
    }
}

// MARK: - Focus

struct FocusSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        SettingsCard(title: "Focus", symbol: "moon.haze.fill") {
            CardRow("Enable Focus Mode", subtitle: "Covers the screen at the selected prayers.") {
                SettingToggle(isOn: state.binding(\.focusModeEnabled))
            }
            CardRow("Duration") {
                Stepper("\(state.settings.focusDurationMinutes) min",
                        value: state.binding(\.focusDurationMinutes), in: 1...120, step: 5)
                    .frame(width: 130)
            }
        }

        SettingsCard(title: "Behaviour", symbol: "slider.horizontal.3") {
            CardRow("Backdrop") {
                SettingPicker(
                    options: BlurIntensity.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.focusBlurIntensity),
                    width: 140
                )
            }
            CardRow("Trigger at") {
                SettingPicker(
                    options: FocusTrigger.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.focusTrigger),
                    width: 190
                )
            }
            CardRow("Allow ⌘⎋ to exit early") {
                SettingToggle(isOn: state.binding(\.focusEmergencyExit))
            }
            HStack {
                CardButton(title: "Try it for 10 seconds", systemImage: "eye") {
                    state.focusMode.preview()
                }
                Spacer()
            }
        }

        SettingsCard(title: nil, symbol: nil) {
            StatusLine(
                text: "Focus Mode covers the screen at the selected prayers. It is a discipline aid, not a lock: Force Quit always works, and it does not engage while another app is presenting full screen.",
                kind: .info
            )
        }
    }
}

// MARK: - About

struct AboutSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandLogo(width: 260)
            Text("Version \(Bundle.main.shortVersion)")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous))

        SettingsCard(title: "Times", symbol: "antenna.radiowaves.left.and.right") {
            CardRow("Source") {
                Text(state.today?.source.label ?? "—").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            CardRow("Method") {
                Text(state.settings.method.name).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            CardRow("Madhab") {
                Text(state.settings.madhab == .hanafi ? "Hanafi" : "Shafi'i")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }

        SettingsCard(title: "Attribution", symbol: "heart.fill", tint: .pink) {
            Text("Prayer times are fetched from the Aladhan API, with an on-device astronomical calculation as the offline fallback. Verified against the live service: mean difference under a minute across every supported method.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension Bundle {
    var shortVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }
}
