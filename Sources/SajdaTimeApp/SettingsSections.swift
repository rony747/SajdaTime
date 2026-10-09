import SwiftUI
import UniformTypeIdentifiers
import SajdaCore

// MARK: - General

struct GeneralSection: View {
    @ObservedObject var state: AppState
    let goTo: (SettingsSection) -> Void

    var body: some View {
        SummaryCard(state: state, goTo: goTo)

        SettingsCard(title: "Location", symbol: "mappin.circle.fill") {
            CardRow("Automatically detect my location") {
                GreenToggle(isOn: Binding(
                    get: { state.settings.locationMode == .automatic },
                    set: { state.settings.locationMode = $0 ? .automatic : .manual }
                ))
            }
            CardRow("Location") {
                HStack(spacing: 8) {
                    GreenPicker(
                        options: [(state.settings.locationName.isEmpty ? "Unknown" : state.settings.locationName,
                                   state.settings.locationName.isEmpty ? "Unknown" : state.settings.locationName)],
                        selection: .constant(state.settings.locationName),
                        width: 210
                    )
                    CardButton(title: "Detect Again", systemImage: "location.fill") {
                        state.location.detectLocation()
                    }
                    .disabled(state.location.isLocating)
                }
            }
            if let message = state.location.errorMessage {
                StatusLine(text: message, kind: .warning)
            }
        }

        SettingsCard(title: "Prayer Times", symbol: "clock.fill") {
            CardRow("Calculation Method") {
                GreenPicker(
                    options: CalculationMethod.all.map { ($0.id, $0.name) },
                    selection: state.binding(\.methodID),
                    width: 250
                )
            }
            CardRow("Madhab (Asr)") {
                GreenSegmented(
                    options: [(Madhab.standard, "Shafi'i"), (Madhab.hanafi, "Hanafi")],
                    selection: state.binding(\.madhab)
                )
                .frame(width: 240)
            }
        }

        NotificationsSummaryCard(state: state, goTo: goTo)

        SettingsCard(title: "Startup & Language", symbol: "power") {
            CardRow("Launch at login", subtitle: "Start Sajda Time automatically when you log in to your Mac.") {
                GreenToggle(isOn: state.binding(\.launchAtLogin))
            }
            CardRow("Language") {
                HStack(spacing: 8) {
                    Image(systemName: "globe").foregroundStyle(.secondary)
                    GreenPicker(
                        options: [(AppLanguage.system, "Follow system"), (AppLanguage.english, "English")],
                        selection: state.binding(\.language),
                        width: 150
                    )
                }
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
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(TimeFormatting.longDate(state.now, timeZone: state.settings.displayTimeZone))
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(.secondary)
                    if state.settings.showHijriDate, let hijri = state.today?.hijri {
                        Text(hijri.formatted)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)

                if let subject = state.countdownSubject {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Next Prayer")
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(subject.prayer.displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("in " + TimeFormatting.countdown(subject.date.timeIntervalSince(state.now)))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.greenDeep)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Artwork gets its own band, so it can never overlap the text.
            BannerArt()
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .clipped()
        }
        .background(Palette.bannerGradient)
        .clipShape(RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous))
        .environment(\.colorScheme, .light)
        .contentShape(Rectangle())
        .onTapGesture { goTo(.prayerTimes) }
    }
}

/// Compact notifications card for the General page.
struct NotificationsSummaryCard: View {
    @ObservedObject var state: AppState
    let goTo: (SettingsSection) -> Void

    var body: some View {
        SettingsCard(title: "Notifications", symbol: "bell.fill") {
            CardRow("Enable prayer time notifications") {
                GreenToggle(isOn: state.binding(\.notificationsEnabled))
            }

            HStack(spacing: 6) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    VStack(spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: prayer.symbolName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.tint(for: prayer))
                            Text(prayer.displayName)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        GreenToggle(isOn: notifyBinding(prayer))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                    )
                }
            }
            .disabled(!state.settings.notificationsEnabled)
            .opacity(state.settings.notificationsEnabled ? 1 : 0.5)

            CardRow("Adhan Sound") {
                HStack(spacing: 8) {
                    GreenPicker(
                        options: NotificationService.availableSounds.map { ($0, $0) },
                        selection: state.binding(\.defaultSoundName),
                        width: 200
                    )
                    CardButton(title: "Play", systemImage: "play.fill") {
                        state.notifications.playSound(named: state.settings.defaultSoundName)
                    }
                    CardButton(title: "Test Sound") {
                        state.notifications.playSound(named: state.settings.defaultSoundName)
                    }
                }
            }
        }
    }

    private func notifyBinding(_ prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { state.settings.reminder(for: prayer).mode != .off },
            set: { on in
                var reminder = state.settings.reminder(for: prayer)
                reminder.mode = on ? .automatic : .off
                state.settings.perPrayer[prayer.rawValue] = reminder
            }
        )
    }
}

// MARK: - Prayer Times

struct PrayerTimesSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        SettingsCard(title: "Source", symbol: "antenna.radiowaves.left.and.right") {
            CardRow("Time source") {
                GreenSegmented(
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
                GreenToggle(isOn: state.binding(\.fetchLiveTimes))
            }
            CardRow("Showing") {
                Text(state.today?.source.label ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }

        SettingsCard(title: "Method", symbol: "function") {
            CardRow("Calculation Method") {
                GreenPicker(
                    options: CalculationMethod.all.map { ($0.id, $0.name) },
                    selection: state.binding(\.methodID),
                    width: 260
                )
            }
            CardRow("Madhab (Asr)") {
                GreenSegmented(
                    options: [(Madhab.standard, "Shafi'i"), (Madhab.hanafi, "Hanafi")],
                    selection: state.binding(\.madhab)
                )
                .frame(width: 240)
            }
            CardRow("High latitude") {
                GreenPicker(
                    options: HighLatitudeRule.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.highLatitudeRule),
                    width: 240
                )
            }
            CardRow("Auto-detect method") {
                GreenToggle(isOn: state.binding(\.autoDetectMethod))
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

    var body: some View {
        SettingsCard(title: "Alerts", symbol: "bell.fill") {
            CardRow("Enable prayer time notifications") {
                GreenToggle(isOn: state.binding(\.notificationsEnabled))
            }
            CardRow("Reminder timing", subtitle: "Applied to every prayer unless overridden below.") {
                GreenPicker(
                    options: [(0, "Off"), (5, "5 min before"), (10, "10 min before"),
                              (15, "15 min before"), (20, "20 min before"), (30, "30 min before")],
                    selection: state.optionalIntBinding(\.defaultEarlyReminderMinutes),
                    width: 170
                )
            }
            CardRow("Iqamah offset") {
                GreenPicker(
                    options: [(0, "Off"), (5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min")],
                    selection: state.optionalIntBinding(\.defaultIqamahMinutes),
                    width: 140
                )
            }
            CardRow("Adhan at prayer time", subtitle: "Plays an audio file you choose; notifications otherwise use the sound above.") {
                GreenToggle(isOn: state.binding(\.playFullAdhan))
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
            HStack {
                CardButton(title: "Send a sample notification", systemImage: "bell.badge") {
                    Task { await state.notifications.sendSample() }
                }
                Spacer()
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
                GreenToggle(isOn: Binding(
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
                        GreenSegmented(
                            options: ReminderMode.allCases.map { ($0, $0.displayName) },
                            selection: state.reminderModeBinding(prayer)
                        )
                        .frame(width: 210)
                    }

                    if reminder.mode == .manual {
                        ForEach(Array(reminder.offsets.enumerated()), id: \.offset) { index, offset in
                            HStack(spacing: 8) {
                                GreenPicker(
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
                        GreenToggle(isOn: state.reminderBinding(prayer, \.playAdhan))
                    }
                    CardRow("Sound") {
                        GreenPicker(
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
                GreenSegmented(
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
                GreenSegmented(
                    options: TimeZoneMode.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.timeZoneMode)
                )
                .frame(width: 240)
            }
            if state.settings.timeZoneMode == .explicit {
                CardRow("Zone") {
                    GreenPicker(
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

    var body: some View {
        SettingsCard(title: "Appearance", symbol: "circle.lefthalf.filled") {
            CardRow("Theme", subtitle: "Applies to the panel and the settings window.") {
                GreenSegmented(
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
                        .foregroundStyle(state.settings.appearance == option ? Palette.greenDeep : Color.secondary)
                    }
                    Spacer()
                }
            }
        }

        SettingsCard(title: "Clock", symbol: "clock.fill") {
            CardRow("Time format", subtitle: "Applies to the panel, the menu bar and all times shown here.") {
                GreenSegmented(
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
                        .foregroundStyle(state.settings.clockFormat == .twelveHour ? Palette.greenDeep : .secondary)
                        .monospacedDigit()
                    Text(ClockFormat.twentyFourHour.example)
                        .font(.system(size: 13, weight: state.settings.clockFormat == .twentyFourHour ? .semibold : .regular,
                                      design: .rounded))
                        .foregroundStyle(state.settings.clockFormat == .twentyFourHour ? Palette.greenDeep : .secondary)
                        .monospacedDigit()
                }
            }
        }

        SettingsCard(title: "Panel", symbol: "rectangle.on.rectangle") {
            CardRow("Show Ishraq time", subtitle: "Adds the voluntary prayer shortly after sunrise.") {
                GreenToggle(isOn: state.binding(\.showIshraq))
            }
            CardRow("Show Hijri date") {
                GreenToggle(isOn: state.binding(\.showHijriDate))
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
                GreenPicker(
                    options: MenuBarLabelStyle.allCases.map { ($0, $0.displayName) },
                    selection: state.binding(\.menuBarLabelStyle),
                    width: 230
                )
            }
            CardRow("Counts down") {
                GreenPicker(
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

        SettingsCard(title: "Startup", symbol: "power") {
            CardRow("Launch at login", subtitle: "Start Sajda Time automatically when you log in to your Mac.") {
                GreenToggle(isOn: state.binding(\.launchAtLogin))
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
