import Foundation
import SwiftUI
import Combine
import PrayerCore

/// Single source of truth for the UI.
///
/// Everything the views need — the current settings, today's times, the ticking
/// clock and the next prayer — lives here, so the menu bar label and the panel
/// can never disagree.
@MainActor
final class AppState: ObservableObject {

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
            settingsDidChange(previous: oldValue)
        }
    }

    @Published private(set) var yesterday: PrayerTimes?
    @Published private(set) var today: PrayerTimes?
    @Published private(set) var tomorrow: PrayerTimes?
    @Published private(set) var now = Date()
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    let notifications = NotificationService()
    let focusMode = FocusModeController()
    let location = LocationService()
    private var cancellables: Set<AnyCancellable> = []

    private let store: PrayerTimesStore
    // Bump this whenever the settings schema changes incompatibly: a stale blob
    // is then ignored and the app starts from timezone-seeded defaults.
    private let defaultsKey = "app.local.prayerbar.settings.v2"
    private var ticker: Timer?
    private var refreshTask: Task<Void, Never>?
    private var lastLoadedDay: Date?
    private var playedAdhanKeys: Set<String> = []

    init(store: PrayerTimesStore = PrayerTimesStore()) {
        self.store = store

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            // First launch, or settings written by an older schema: seed the
            // location from the system timezone. The old hard-coded default was
            // Istanbul, which showed Istanbul's times to everyone else.
            settings = AppSettings.fresh(for: .current)
        }

        startTicking()

        // Let observers of AppState re-render when the location service changes.
        location.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        location.onResolved = { [weak self] fix, placemark in
            guard let self else { return }
            var updated = self.settings
            updated.latitude = fix.coordinate.latitude
            updated.longitude = fix.coordinate.longitude
            updated.locationIsEstimated = false
            if let city = placemark?.locality ?? placemark?.administrativeArea, !city.isEmpty {
                updated.locationName = city
            }
            if let country = placemark?.isoCountryCode, !country.isEmpty {
                updated.countryCode = country
                if updated.autoDetectMethod {
                    updated.methodID = CalculationMethod.autoDetected(forCountryCode: country).id
                }
            }
            self.settings = updated
        }

        Task { await refresh() }
        detectLocationIfNeeded()
    }

    /// Ask for a position when all we have is a timezone-derived guess.
    func detectLocationIfNeeded() {
        guard settings.locationMode == .automatic else { return }
        guard settings.locationIsEstimated || !settings.hasUsableLocation else { return }
        location.detectLocation()
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    // MARK: - Clock

    private func startTicking() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common keeps the countdown updating while a menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        now = Date()
        // Roll over to the new day shortly after midnight.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.displayTimeZone
        let currentDay = calendar.startOfDay(for: now)
        if let lastLoadedDay, lastLoadedDay != currentDay {
            Task { await refresh() }
        }
        focusMode.evaluate(times: today, settings: settings, now: now)
        evaluateAdhanPlayback()
    }

    /// Plays the adhan when a prayer time is reached while the app is running.
    ///
    /// The notification supplies the alert; this supplies the audio, because
    /// notification sounds have to live inside the app bundle and the user's own
    /// adhan recording does not.
    private func evaluateAdhanPlayback() {
        guard settings.notificationsEnabled, let today else { return }
        for prayer in Prayer.obligatory {
            guard let prayerTime = today.times[prayer] else { continue }
            // Only fire on the minute the prayer starts, so a missed tick does
            // not replay every adhan for the rest of the day.
            guard now >= prayerTime, now.timeIntervalSince(prayerTime) < 60 else { continue }

            let key = "\(prayer.rawValue)-\(Int(prayerTime.timeIntervalSince1970))"
            guard !playedAdhanKeys.contains(key) else { continue }
            playedAdhanKeys.insert(key)

            let reminder = settings.reminder(for: prayer)
            guard reminder.playAdhan || settings.playFullAdhan else { continue }

            if let path = settings.adhanAudioPath, FileManager.default.fileExists(atPath: path) {
                notifications.playAudioFile(at: path)
            } else {
                notifications.playSound(named: reminder.soundName ?? settings.defaultSoundName)
            }
        }
        // Keep the set from growing without bound across days.
        if playedAdhanKeys.count > 64 {
            playedAdhanKeys.removeAll()
        }
    }

    /// Drop fetched days so the next refresh hits the network.
    func clearCachedTimes() {
        PrayerTimesCache().clearAll()
        objectWillChange.send()
        Task { await refresh() }
    }

    // MARK: - Loading

    func refresh() async {
        refreshTask?.cancel()
        let task = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            let zone = settings.displayTimeZone
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let dayStart = calendar.startOfDay(for: now)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart

            let loadedYesterday = await store.times(for: settings, date: previousDay)
            let loadedToday = await store.times(for: settings, date: dayStart)
            let loadedTomorrow = await store.times(for: settings, date: nextDay)

            guard !Task.isCancelled else { return }
            yesterday = loadedYesterday
            today = loadedToday
            tomorrow = loadedTomorrow
            lastLoadedDay = dayStart
            lastUpdated = Date()
            lastError = loadedToday.times.isEmpty ? "No prayer times available for today." : nil

            notifications.reschedule(settings: settings, from: now)
        }
        refreshTask = task
        await task.value
    }

    private func settingsDidChange(previous: AppSettings) {
        // Changing the timezone or location invalidates the whole day.
        Task { await refresh() }
        if previous.launchAtLogin != settings.launchAtLogin {
            LoginItem.setEnabled(settings.launchAtLogin)
        }
        if previous.notificationsEnabled != settings.notificationsEnabled {
            if settings.notificationsEnabled {
                Task { await notifications.requestAuthorization() }
            }
        }
    }

    func applyLocation(latitude: Double, longitude: Double, name: String?, countryCode: String?) {
        var updated = settings
        updated.latitude = latitude
        updated.longitude = longitude
        if let name, !name.isEmpty { updated.locationName = name }
        if let countryCode, !countryCode.isEmpty {
            updated.countryCode = countryCode
            if updated.autoDetectMethod {
                updated.methodID = CalculationMethod.autoDetected(forCountryCode: countryCode).id
            }
        }
        settings = updated
    }

    // MARK: - Derived state

    /// The next prayer, looking into tomorrow when today is finished.
    var nextPrayer: (prayer: Prayer, date: Date)? {
        if let today, let next = today.nextPrayer(after: now) {
            return next
        }
        if let tomorrow, let fajr = tomorrow.times[.fajr] {
            return (.fajr, fajr)
        }
        return nil
    }

    /// The prayer window currently open, if any.
    ///
    /// Nil during the two daily gaps where no obligatory prayer is in its chosen
    /// time: between sunrise and Dhuhr, and between Islamic midnight and Fajr.
    var activeWindow: PrayerWindow? {
        today?.activeWindow(at: now, previousDay: yesterday, nextDay: tomorrow)
    }

    /// What the menu bar and the panel header should present.
    ///
    /// `currentWindowEnd` counts down the valid time left for the prayer you can
    /// currently pray — Fajr's remaining time is to sunrise, not to Dhuhr.
    /// `nextPrayer` counts down to the next prayer that begins.
    var countdownSubject: CountdownSubject? {
        switch settings.countdownTarget {
        case .currentWindowEnd:
            if let window = activeWindow {
                return CountdownSubject(
                    prayer: window.prayer,
                    date: window.end,
                    isWindowEnd: true,
                    window: window
                )
            }
            return nextPrayer.map { CountdownSubject(prayer: $0.prayer, date: $0.date, isWindowEnd: false, window: nil) }
        case .nextPrayer:
            return nextPrayer.map { CountdownSubject(prayer: $0.prayer, date: $0.date, isWindowEnd: false, window: nil) }
        }
    }

    /// What the menu bar label and panel header are counting towards.
    struct CountdownSubject {
        let prayer: Prayer
        let date: Date
        /// True when `date` is the end of `prayer`'s own window.
        let isWindowEnd: Bool
        let window: PrayerWindow?
    }

    var countdownRemaining: TimeInterval? {
        guard let subject = countdownSubject else { return nil }
        return subject.date.timeIntervalSince(now)
    }

    /// Exactly what the menu bar should render.
    var menuBarContent: MenuBarContent {
        let subject = countdownSubject
        return MenuBarComposer.content(
            style: settings.menuBarLabelStyle,
            prayerName: subject?.prayer.displayName ?? "—",
            prayerSymbol: subject?.prayer.symbolName ?? "moon.stars",
            countdown: compactCountdown
        )
    }

    /// Hover text for the menu bar item, so the full context is available even
    /// when the label itself is narrow.
    var statusTooltip: String {
        guard let subject = countdownSubject else { return "PrayerBar" }
        let clock = DateFormatter()
        clock.timeZone = settings.displayTimeZone
        clock.dateFormat = "h:mm a"
        let when = clock.string(from: subject.date)
        let scope = subject.isWindowEnd ? "time left" : "until"
        return "\(subject.prayer.displayName) — \(compactCountdown) \(scope) \(when)"
    }

    /// e.g. "25m" — the compact form used in the menu bar and the list pill.
    var compactCountdown: String {
        guard let remaining = countdownRemaining, remaining > 0 else { return "--" }
        let totalMinutes = Int(remaining / 60)
        if totalMinutes < 1 { return "<1m" }
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    /// e.g. "0:25:34" — the precise form shown in the panel header.
    var preciseCountdown: String {
        guard let remaining = countdownRemaining, remaining > 0 else { return "--:--:--" }
        let total = Int(remaining)
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// The row that should be highlighted in the list: the next event.
    var highlightedPrayer: Prayer? {
        countdownSubject?.prayer
    }

    func remaining(until date: Date) -> TimeInterval {
        date.timeIntervalSince(now)
    }

    /// e.g. "in 0:25:34", matching the reference panel.
    func relativeText(to date: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 {
            return "now"
        }
        let total = Int(remaining)
        return String(format: "in %d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// e.g. "0:25:34 left" when a prayer's own window is closing, otherwise the
    /// same "in 0:25:34" phrasing used for an upcoming prayer.
    func countdownText(for subject: CountdownSubject) -> String {
        let remaining = subject.date.timeIntervalSince(now)
        guard remaining > 0 else { return "now" }
        let total = Int(remaining)
        let clock = String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        return subject.isWindowEnd ? "\(clock) left" : "in \(clock)"
    }
}
