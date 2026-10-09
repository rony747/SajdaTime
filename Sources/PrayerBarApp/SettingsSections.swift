import SwiftUI
import UniformTypeIdentifiers
import PrayerCore

// MARK: - Overview

struct OverviewSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        Section("Startup") {
            Toggle("Launch at login", isOn: state.binding(\.launchAtLogin))
        }

        Section("Menu bar") {
            Picker("Shows", selection: state.binding(\.menuBarLabelStyle)) {
                ForEach(MenuBarLabelStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Counts down", selection: state.binding(\.countdownTarget)) {
                ForEach(CountdownTarget.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }

        Section("Panel") {
            Toggle("Show Ishraq time", isOn: state.binding(\.showIshraq))
            Toggle("Show Hijri date", isOn: state.binding(\.showHijriDate))
        }

        Section("Stored data") {
            LabeledContent("Cached days", value: CacheInfo.describe())
            Button("Clear cached times") { state.clearCachedTimes() }
        }

        Section("About") {
            LabeledContent("Version", value: Bundle.main.shortVersion)
            LabeledContent("Fetched for", value: state.settings.locationName.isEmpty ? "—" : state.settings.locationName)
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

extension Bundle {
    var shortVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }
}

// MARK: - Place & time

struct PlaceSection: View {
    @ObservedObject var state: AppState

    private static let zones = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        Section("Position") {
            Picker("Mode", selection: state.binding(\.locationMode)) {
                ForEach(LocationMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Button {
                state.location.detectLocation()
            } label: {
                if state.location.isLocating {
                    Label("Locating…", systemImage: "location.fill")
                } else {
                    Label("Detect my location", systemImage: "location.fill")
                }
            }
            .disabled(state.location.isLocating)

            if let message = state.location.errorMessage {
                StatusLine(text: message, kind: .warning)
            }
            if state.settings.locationIsEstimated {
                StatusLine(
                    text: "Position estimated from your timezone until a real fix arrives.",
                    kind: .info
                )
            }

            LabeledContent("Latitude") {
                TextField("", value: state.userCoordinateBinding(\.latitude),
                          format: .number.precision(.fractionLength(0...6)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Longitude") {
                TextField("", value: state.userCoordinateBinding(\.longitude),
                          format: .number.precision(.fractionLength(0...6)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Elevation") {
                TextField("", value: state.binding(\.elevation),
                          format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                Text("m").foregroundStyle(.secondary)
            }
            LabeledContent("Place", value: state.settings.locationName.isEmpty ? "—" : state.settings.locationName)
        }

        Section("Timezone") {
            Picker("Show times on", selection: state.binding(\.timeZoneMode)) {
                ForEach(TimeZoneMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if state.settings.timeZoneMode == .explicit {
                Picker("Zone", selection: state.binding(\.explicitTimeZoneID)) {
                    ForEach(Self.zones, id: \.self) { Text($0).tag($0) }
                }
            }
        }

        Section("Hijri date") {
            Stepper("Day adjustment: \(state.settings.hijriDayAdjustment)",
                    value: state.binding(\.hijriDayAdjustment), in: -3...3)
            LabeledContent("Today", value: state.today?.hijri?.formatted ?? "—")
        }
    }
}

// MARK: - Method

struct MethodSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        Section("Time source") {
            Picker("Source", selection: state.binding(\.timeSourceMode)) {
                ForEach(TimeSourceMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if state.settings.timeSourceMode == .manual {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    LabeledContent(prayer.displayName) {
                        TextField("HH:mm", text: manualTimeBinding(prayer))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }

        Section("Calculation") {
            Picker("Method", selection: state.binding(\.methodID)) {
                ForEach(CalculationMethod.all) { Text($0.name).tag($0.id) }
            }
            Picker("Asr", selection: state.binding(\.madhab)) {
                ForEach(Madhab.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("High latitude", selection: state.binding(\.highLatitudeRule)) {
                ForEach(HighLatitudeRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }

        Section("Automation") {
            Toggle("Auto-detect method from place", isOn: state.binding(\.autoDetectMethod))
            if state.settings.autoDetectMethod {
                StatusLine(
                    text: "Using \(state.settings.method.name) for \(state.settings.countryCode.isEmpty ? "this region" : state.settings.countryCode).",
                    kind: .info
                )
            }
        }

        Section("Live data") {
            Toggle("Fetch times from Aladhan", isOn: state.binding(\.fetchLiveTimes))
            LabeledContent("Showing", value: state.today?.source.label ?? "—")
            if state.today?.usedPolarFallback == true {
                StatusLine(
                    text: "No sunrise or sunset on this date, so the angle-based times come from a mid-latitude reference.",
                    kind: .warning
                )
            }
        }

        Section("Fine tuning") {
            ForEach(Prayer.allCases, id: \.self) { prayer in
                Stepper(
                    "\(prayer.displayName): \(Int(state.settings.userAdjustments[prayer.rawValue] ?? 0)) min",
                    value: adjustmentBinding(prayer),
                    in: -60...60
                )
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

// MARK: - Reminders

struct ReminderSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        Section("Reminders") {
            Toggle("Enable reminders", isOn: state.binding(\.notificationsEnabled))
            Button("Send a sample notification") {
                Task { await state.notifications.sendSample() }
            }
            if let error = state.notifications.lastError {
                StatusLine(text: error, kind: .error)
            }
            if state.notifications.authorizationStatus == .denied {
                StatusLine(text: "Reminders are blocked in System Settings › Notifications.", kind: .error)
            }
        }

        Section("Defaults") {
            Picker("Sound", selection: state.binding(\.defaultSoundName)) {
                ForEach(NotificationService.availableSounds, id: \.self) { Text($0).tag($0) }
            }
            Button("Preview sound") {
                state.notifications.playSound(named: state.settings.defaultSoundName)
            }
            Toggle("Play full adhan audio", isOn: state.binding(\.playFullAdhan))
            if state.settings.playFullAdhan {
                LabeledContent("Audio file") {
                    Text(state.settings.adhanAudioPath.map { ($0 as NSString).lastPathComponent } ?? "none chosen")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button("Choose audio file…") { chooseAdhanFile() }
            }
            Picker("Early reminder", selection: state.optionalIntBinding(\.defaultEarlyReminderMinutes)) {
                Text("Off").tag(0)
                ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0) min before").tag($0) }
            }
            Picker("Iqamah offset", selection: state.optionalIntBinding(\.defaultIqamahMinutes)) {
                Text("Off").tag(0)
                ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) min").tag($0) }
            }
        }

        Section("Per prayer") {
            ForEach(Prayer.obligatory, id: \.self) { prayer in
                prayerDisclosure(prayer)
            }
        }
    }

    private func prayerDisclosure(_ prayer: Prayer) -> some View {
        let reminder = state.settings.reminder(for: prayer)
        return DisclosureGroup {
            Picker("Timing", selection: state.reminderModeBinding(prayer)) {
                ForEach(ReminderMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if reminder.mode == .manual {
                ForEach(Array(reminder.offsets.enumerated()), id: \.offset) { index, offset in
                    HStack {
                        Picker("", selection: offsetAnchorBinding(prayer, index)) {
                            ForEach(ReminderOffset.Anchor.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 100)

                        Stepper("\(offset.minutes) min", value: offsetMinutesBinding(prayer, index), in: 0...120, step: 5)

                        Button {
                            removeOffset(prayer, index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(reminder.offsets.count <= 1)
                    }
                }
                Button("Add a reminder") { addOffset(prayer) }
            }

            Toggle("Adhan at prayer time", isOn: state.reminderBinding(prayer, \.playAdhan))

            Picker("Sound", selection: Binding(
                get: { reminder.soundName ?? "" },
                set: { value in
                    var updated = reminder
                    updated.soundName = value.isEmpty ? nil : value
                    state.settings.perPrayer[prayer.rawValue] = updated
                }
            )) {
                Text("App default").tag("")
                ForEach(NotificationService.availableSounds, id: \.self) { Text($0).tag($0) }
            }

            Picker("Iqamah", selection: Binding(
                get: { reminder.iqamahMinutes ?? -1 },
                set: { value in
                    var updated = reminder
                    updated.iqamahMinutes = value < 0 ? nil : value
                    state.settings.perPrayer[prayer.rawValue] = updated
                }
            )) {
                Text("App default").tag(-1)
                Text("Off").tag(0)
                ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) min").tag($0) }
            }
        } label: {
            HStack {
                Label(prayer.displayName, systemImage: prayer.symbolName)
                Spacer()
                Text(reminder.mode == .off ? "off" : reminder.mode.displayName.lowercased())
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
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

// MARK: - Focus

struct FocusSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        Section("Focus") {
            Toggle("Enable Focus Mode", isOn: state.binding(\.focusModeEnabled))
            Stepper("Duration: \(state.settings.focusDurationMinutes) min",
                    value: state.binding(\.focusDurationMinutes), in: 1...120, step: 5)
        }

        Section("Behaviour") {
            Picker("Backdrop", selection: state.binding(\.focusBlurIntensity)) {
                ForEach(BlurIntensity.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Trigger at", selection: state.binding(\.focusTrigger)) {
                ForEach(FocusTrigger.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Toggle("Allow ⌘⎋ to exit early", isOn: state.binding(\.focusEmergencyExit))
        }

        Section {
            Button("Try it for 10 seconds") { state.focusMode.preview() }
        }

        Section {
            StatusLine(
                text: "Focus Mode covers the screen at the selected prayers. It is a discipline aid, not a lock: Force Quit always works, and it does not engage while another app is presenting full screen.",
                kind: .info
            )
        }
    }
}
