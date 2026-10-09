import SwiftUI
import UniformTypeIdentifiers
import PrayerCore

// MARK: - General

struct GeneralSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Startup")
            SettingsCard {
                SettingsRow("Launch at login", showsDivider: false) {
                    AccentToggle(isOn: state.binding(\.launchAtLogin))
                }
            }

            SettingsSectionHeader(title: "Menu bar")
            SettingsCard {
                SettingsRow("Label style") {
                    MenuPicker(
                        options: MenuBarLabelStyle.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.menuBarLabelStyle),
                        width: 190
                    )
                }
                SettingsRow("Countdown shows", showsDivider: false) {
                    MenuPicker(
                        options: CountdownTarget.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.countdownTarget),
                        width: 210
                    )
                }
            }

            SettingsSectionHeader(title: "Panel")
            SettingsCard {
                SettingsRow("Show Ishraq time") {
                    AccentToggle(isOn: state.binding(\.showIshraq))
                }
                SettingsRow("Show Hijri date", showsDivider: false) {
                    AccentToggle(isOn: state.binding(\.showHijriDate))
                }
            }

            SettingsSectionHeader(title: "Language")
            SettingsCard {
                SettingsRow("Language") {
                    MenuPicker(
                        options: AppLanguage.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.language),
                        width: 170
                    )
                }
                SettingsNote(text: "Changing the language relaunches the app.")
            }

            SettingsSectionHeader(title: "Stored data")
            SettingsCard {
                SettingsRow("Cached days", subtitle: CacheInfo.describe()) {
                    ActionButton(title: "Clear", systemImage: "trash") {
                        state.clearCachedTimes()
                    }
                }
                SettingsNote(text: "Fetched days are cached so the app opens instantly and keeps working offline. Clearing them only forces a re-fetch.")
            }
        }
    }
}

/// Small helper so the General tab can report on the on-disk cache.
enum CacheInfo {
    static func describe() -> String {
        let directory = PrayerTimesCache.defaultDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let days = contents.filter { $0.pathExtension == "json" }.count
        return days == 1 ? "1 day" : "\(days) days"
    }
}

// MARK: - Location & Time

struct LocationSettingsTab: View {
    @ObservedObject var state: AppState

    private static let timeZoneIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Location")
            SettingsCard {
                SettingsRow("Mode") {
                    SegmentedPicker(
                        options: LocationMode.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.locationMode)
                    )
                    .frame(width: 200)
                }

                if state.settings.locationMode == .automatic {
                    SettingsRow("", showsDivider: false) {
                        HStack {
                            Spacer()
                            ActionButton(
                                title: state.location.isLocating ? "Locating…" : "Detect my location",
                                systemImage: "location.fill",
                                isBusy: state.location.isLocating
                            ) {
                                state.location.detectLocation()
                            }
                        }
                    }
                }

                if let message = state.location.errorMessage {
                    InlineError(message: message)
                }

                SettingsRow("Latitude") {
                    numberField(userCoordinateBinding(\.latitude), width: 110)
                }
                SettingsRow("Longitude") {
                    numberField(userCoordinateBinding(\.longitude), width: 110)
                }
                SettingsRow("Elevation (m)", subtitle: "Used for the horizon dip", showsDivider: true) {
                    TextField("", value: state.binding(\.elevation), format: .number.precision(.fractionLength(0...1)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 12))
                        .frame(width: 80)
                }
                SettingsRow("Place", subtitle: state.settings.locationName, showsDivider: false) {
                    Text(state.settings.countryCode.isEmpty ? "—" : state.settings.countryCode)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSectionHeader(title: "Master timezone")
            SettingsCard {
                SettingsRow("Timezone", showsDivider: state.settings.timeZoneMode == .explicit) {
                    SegmentedPicker(
                        options: TimeZoneMode.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.timeZoneMode)
                    )
                    .frame(width: 230)
                }
                if state.settings.timeZoneMode == .explicit {
                    SettingsRow("Zone", showsDivider: false) {
                        MenuPicker(
                            options: Self.timeZoneIdentifiers.map { ($0, $0) },
                            selection: state.binding(\.explicitTimeZoneID),
                            width: 220
                        )
                    }
                }
            }
            SettingsNote(text: "Times are computed for the location above, then shown on this timezone's clock. Changing it shifts every displayed time, which is what you want when travelling but not when correcting a city's zone.")

            SettingsSectionHeader(title: "Hijri date")
            SettingsCard {
                SettingsRow("Day adjustment", subtitle: "Shift for local moon sighting") {
                    ValueStepper(value: state.binding(\.hijriDayAdjustment), range: -3...3, suffix: "days")
                }
                SettingsRow("Today", showsDivider: false) {
                    Text(state.today?.hijri?.formatted ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Editing a coordinate by hand makes it the user's own choice, so the
    /// "estimated from your timezone" caveat no longer applies.
    private func userCoordinateBinding(_ keyPath: WritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding(
            get: { state.settings[keyPath: keyPath] },
            set: { value in
                state.settings[keyPath: keyPath] = value
                state.settings.locationIsEstimated = false
                state.settings.locationMode = .manual
            }
        )
    }

    private func numberField(_ binding: Binding<Double>, width: CGFloat) -> some View {
        TextField("", value: binding, format: .number.precision(.fractionLength(0...6)))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 12))
            .frame(width: width)
    }
}

// MARK: - Calculation

struct CalculationSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Source")
            SettingsCard {
                SettingsRow("Time source", showsDivider: false) {
                    SegmentedPicker(
                        options: TimeSourceMode.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.timeSourceMode)
                    )
                    .frame(width: 230)
                }
            }
            SettingsNote(text: state.settings.timeSourceMode == .astronomical
                ? "Times are computed astronomically from your location, matching the method below."
                : "Times are the fixed values you enter below and are not recalculated.")

            if state.settings.timeSourceMode == .manual {
                SettingsSectionHeader(title: "Fixed times")
                SettingsCard {
                    ForEach(Array(Prayer.allCases.enumerated()), id: \.element) { index, prayer in
                        SettingsRow(prayer.displayName, showsDivider: index < Prayer.allCases.count - 1) {
                            TextField("HH:mm", text: manualTimeBinding(prayer))
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 80)
                        }
                    }
                }
            }

            SettingsSectionHeader(title: "Method")
            SettingsCard {
                SettingsRow("Calculation method") {
                    MenuPicker(
                        options: CalculationMethod.all.map { ($0.id, $0.name) },
                        selection: state.binding(\.methodID),
                        width: 240
                    )
                }
                SettingsRow("Asr (madhab)") {
                    MenuPicker(
                        options: Madhab.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.madhab),
                        width: 240
                    )
                }
                SettingsRow("High-latitude rule", showsDivider: false) {
                    MenuPicker(
                        options: HighLatitudeRule.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.highLatitudeRule),
                        width: 240
                    )
                }
            }

            SettingsSectionHeader(title: "Automation")
            SettingsCard {
                SettingsRow("Auto-detect method from location", showsDivider: false) {
                    AccentToggle(isOn: state.binding(\.autoDetectMethod))
                }
            }
            SettingsNote(text: state.settings.autoDetectMethod
                ? "Detected \(state.settings.method.name) for \(state.settings.countryCode.isEmpty ? "this country" : state.settings.countryCode) when your location was last set."
                : "The method above is used as-is.")

            SettingsSectionHeader(title: "Live data")
            SettingsCard {
                SettingsRow("Fetch times from Aladhan", subtitle: "Falls back to on-device calculation when offline") {
                    AccentToggle(isOn: state.binding(\.fetchLiveTimes))
                }
                SettingsRow("Currently showing", showsDivider: false) {
                    Text(state.today?.source.label ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSectionHeader(title: "Tuning")
            SettingsCard {
                ForEach(Array(Prayer.allCases.enumerated()), id: \.element) { index, prayer in
                    SettingsRow(prayer.displayName, subtitle: "Minutes added to the calculated time", showsDivider: index < Prayer.allCases.count - 1) {
                        ValueStepper(value: adjustmentBinding(prayer), range: -60...60, suffix: "min")
                    }
                }
            }
            SettingsNote(text: "These are applied on top of the method's own offsets, and are also sent to Aladhan when live times are fetched.")
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

struct NotificationSettingsTab: View {
    @ObservedObject var state: AppState
    @State private var expandedPrayer: Prayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Notifications")
            SettingsCard {
                SettingsRow(
                    "Enable notifications",
                    subtitle: "Master switch for all prayer alerts.",
                    showsDivider: true
                ) {
                    AccentToggle(isOn: state.binding(\.notificationsEnabled))
                }
                SettingsRow("", showsDivider: false) {
                    HStack {
                        Spacer()
                        ActionButton(title: "Send a sample notification", systemImage: "bell.badge") {
                            Task { await state.notifications.sendSample() }
                        }
                    }
                }
                if let error = state.notifications.lastError {
                    InlineError(message: error)
                }
                if state.notifications.authorizationStatus == .denied {
                    InlineError(message: "Notifications are blocked in System Settings › Notifications › PrayerBar.")
                }
            }

            SettingsSectionHeader(title: "Defaults")
            SettingsCard {
                SettingsRow("Default sound") {
                    HStack(spacing: 6) {
                        Button {
                            state.notifications.playSound(named: state.settings.defaultSoundName)
                        } label: {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Preview this sound")
                        MenuPicker(
                            options: NotificationService.availableSounds.map { ($0, $0) },
                            selection: state.binding(\.defaultSoundName),
                            width: 140
                        )
                    }
                }
                SettingsRow("Play full Adhan audio", subtitle: adhanSubtitle) {
                    AccentToggle(isOn: state.binding(\.playFullAdhan))
                }
                if state.settings.playFullAdhan {
                    SettingsRow("", showsDivider: true) {
                        HStack {
                            Spacer()
                            ActionButton(title: state.settings.adhanAudioPath == nil ? "Choose audio file…" : "Change audio file…", systemImage: "folder") {
                                chooseAdhanFile()
                            }
                        }
                    }
                }
                SettingsRow("Early reminder") {
                    MenuPicker(
                        options: [(0, "Off"), (5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min"), (30, "30 min")],
                        selection: state.optionalIntBinding(\.defaultEarlyReminderMinutes),
                        width: 120
                    )
                }
                SettingsRow("Iqamah / jamaat offset", showsDivider: false) {
                    MenuPicker(
                        options: [(0, "Off"), (5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min")],
                        selection: state.optionalIntBinding(\.defaultIqamahMinutes),
                        width: 120
                    )
                }
            }
            SettingsNote(text: "Applied to every prayer. Expand a prayer below to override its sound, reminder timing, or iqamah.")

            SettingsSectionHeader(title: "Per prayer")
            SettingsCard {
                tableHeader
                ForEach(Array(Prayer.obligatory.enumerated()), id: \.element) { index, prayer in
                    prayerRow(prayer, isLast: index == Prayer.obligatory.count - 1)
                    if expandedPrayer == prayer {
                        offsetEditor(for: prayer)
                    }
                }
            }
        }
    }

    private var adhanSubtitle: String {
        if let path = state.settings.adhanAudioPath {
            return "Playing \((path as NSString).lastPathComponent)"
        }
        return "Choose an audio file to play at prayer time"
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("").frame(width: 20)
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            Text("NOTIFY").frame(width: 54)
            Text("ADHAN").frame(width: 54)
            Text("REMIND").frame(width: 56)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func prayerRow(_ prayer: Prayer, isLast: Bool) -> some View {
        let reminder = state.settings.reminder(for: prayer)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: prayer.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(prayer.displayName)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
                AccentToggle(isOn: Binding(
                    get: { reminder.mode != .off },
                    set: { on in state.reminderModeBinding(prayer).wrappedValue = on ? .automatic : .off }
                ))
                .frame(width: 54)
                AccentToggle(isOn: state.reminderBinding(prayer, \.playAdhan))
                    .frame(width: 54)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expandedPrayer = expandedPrayer == prayer ? nil : prayer
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundStyle(expandedPrayer == prayer ? Theme.accent : Color.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 56)
                .help("Customise this prayer's reminder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !isLast || expandedPrayer == prayer {
                Divider().padding(.leading, 12)
            }
        }
    }

    @ViewBuilder
    private func offsetEditor(for prayer: Prayer) -> some View {
        let reminder = state.settings.reminder(for: prayer)
        VStack(alignment: .leading, spacing: 10) {
            SettingsRow("Timing", subtitle: "Auto follows the defaults above") {
                SegmentedPicker(
                    options: ReminderMode.allCases.map { ($0, $0.displayName) },
                    selection: state.reminderModeBinding(prayer)
                )
                .frame(width: 190)
            }

            if reminder.mode == .manual {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(reminder.offsets.enumerated()), id: \.offset) { index, offset in
                        HStack(spacing: 6) {
                            MenuPicker(
                                options: ReminderOffset.Anchor.allCases.map { ($0, $0.displayName) },
                                selection: offsetAnchorBinding(prayer, index),
                                width: 90
                            )
                            Stepper(
                                value: offsetMinutesBinding(prayer, index),
                                in: 0...120,
                                step: 5
                            ) {
                                Text("\(offset.minutes) min")
                                    .font(.system(size: 12))
                                    .monospacedDigit()
                                    .frame(width: 60, alignment: .leading)
                            }
                            .controlSize(.small)
                            Button {
                                removeOffset(prayer, index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .disabled(reminder.offsets.count <= 1)
                        }
                    }
                    ActionButton(title: "Add reminder", systemImage: "plus") {
                        addOffset(prayer)
                    }
                }
                .padding(.horizontal, 12)
            }

            SettingsRow("Sound", subtitle: "Leave as default to use the app default") {
                MenuPicker(
                    options: [("", "Default")] + NotificationService.availableSounds.map { ($0, $0) },
                    selection: Binding(
                        get: { reminder.soundName ?? "" },
                        set: { value in
                            var updated = reminder
                            updated.soundName = value.isEmpty ? nil : value
                            state.settings.perPrayer[prayer.rawValue] = updated
                        }
                    ),
                    width: 130
                )
            }

            SettingsRow("Iqamah after", subtitle: "Overrides the default offset") {
                MenuPicker(
                    options: [(-1, "Default"), (0, "Off"), (5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min")],
                    selection: Binding(
                        get: { reminder.iqamahMinutes ?? -1 },
                        set: { value in
                            var updated = reminder
                            updated.iqamahMinutes = value < 0 ? nil : value
                            state.settings.perPrayer[prayer.rawValue] = updated
                        }
                    ),
                    width: 120
                )
            }
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.025))
    }

    private func offsetAnchorBinding(_ prayer: Prayer, _ index: Int) -> Binding<ReminderOffset.Anchor> {
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

    private func offsetMinutesBinding(_ prayer: Prayer, _ index: Int) -> Binding<Int> {
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

    private func addOffset(_ prayer: Prayer) {
        var reminder = state.settings.reminder(for: prayer)
        reminder.mode = .manual
        reminder.offsets.append(ReminderOffset(anchor: .before, minutes: 10))
        state.settings.perPrayer[prayer.rawValue] = reminder
    }

    private func removeOffset(_ prayer: Prayer, _ index: Int) {
        var reminder = state.settings.reminder(for: prayer)
        guard index < reminder.offsets.count else { return }
        reminder.offsets.remove(at: index)
        state.settings.perPrayer[prayer.rawValue] = reminder
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

// MARK: - Focus Mode

struct FocusModeSettingsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: "Focus Mode")
            SettingsCard {
                SettingsRow(
                    "Enable Focus Mode",
                    subtitle: "Covers the entire screen during prayer time",
                    showsDivider: false
                ) {
                    AccentToggle(isOn: state.binding(\.focusModeEnabled))
                }
            }

            SettingsSectionHeader(title: "Behaviour")
            SettingsCard {
                SettingsRow("Prayer duration") {
                    ValueStepper(value: state.binding(\.focusDurationMinutes), range: 1...120, suffix: "minutes", step: 5)
                }
                SettingsRow("Blur intensity") {
                    MenuPicker(
                        options: BlurIntensity.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.focusBlurIntensity),
                        width: 130
                    )
                }
                SettingsRow("Trigger on") {
                    MenuPicker(
                        options: FocusTrigger.allCases.map { ($0, $0.displayName) },
                        selection: state.binding(\.focusTrigger),
                        width: 170
                    )
                }
                SettingsRow(
                    "Emergency exit",
                    subtitle: "Allow ⌘⎋ to exit early",
                    showsDivider: false
                ) {
                    AccentToggle(isOn: state.binding(\.focusEmergencyExit))
                }
            }

            SettingsCard {
                SettingsRow("", showsDivider: false) {
                    ActionButton(title: "Try it for 10 seconds", systemImage: "eye") {
                        state.focusMode.preview()
                    }
                }
            }
            .padding(.top, 8)

            SettingsCard {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Focus Mode covers your whole screen at each selected prayer. It's a discipline aid, not a lock — Force Quit always works, ⌘⎋ exits early when Emergency exit is on, and it won't engage while a fullscreen app (a call or presentation) is frontmost.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(12)
            }
            .padding(.top, 8)
        }
    }
}
