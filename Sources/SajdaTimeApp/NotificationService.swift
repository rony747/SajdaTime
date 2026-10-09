import Foundation
import AppKit
import UserNotifications
import SajdaCore

/// Schedules prayer reminders and plays sounds.
///
/// Two mechanisms run side by side, on purpose:
///   * `UNUserNotificationCenter` so an alert appears through Notification
///     Center even when the app is in the background;
///   * an in-app timer so the app can play the chosen chime or adhan, which the
///     notification system cannot do with arbitrary user files.
@MainActor
final class NotificationService: NSObject, ObservableObject {

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    /// How many days ahead to pre-schedule. macOS caps pending notifications, so
    /// this is refreshed on every launch and day change.
    private let schedulingHorizonDays = 7

    /// Sound palette. These are the standard macOS alert sounds, so every option
    /// is a real sound rather than a label with nothing behind it.
    static let availableSounds = [
        "Soft chime", "Glass", "Ping", "Pop", "Purr", "Submarine", "Tink", "Hero", "Funk", "Basso",
    ]

    override init() {
        super.init()
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Ask once; safe to call repeatedly.
    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            lastError = error.localizedDescription
        }
        await refreshAuthorizationStatus()
    }

    /// Replace all pending prayer reminders with a fresh window.
    func reschedule(settings: AppSettings, from date: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard settings.notificationsEnabled, authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        let zone = settings.displayTimeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        for dayOffset in 0..<schedulingHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: date)) else { continue }
            let dayTimes = PrayerCalculator.calculate(
                date: day,
                coordinate: settings.coordinate,
                timeZone: zone,
                options: settings.calculationOptions
            )

            for prayer in Prayer.obligatory {
                guard let prayerTime = dayTimes.times[prayer] else { continue }
                let reminder = settings.reminder(for: prayer)
                let offsets = reminder.effectiveOffsets(defaults: settings.defaultOffsets)
                guard !offsets.isEmpty else { continue }

                for offset in offsets {
                    let fireDate = prayerTime.addingTimeInterval(offset.secondsFromPrayer)
                    guard fireDate > date else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = notificationTitle(prayer: prayer, offset: offset)
                    content.body = bodyText(prayer: prayer, offset: offset, time: prayerTime, zone: zone)
                    content.sound = .default
                    content.userInfo = ["prayer": prayer.rawValue]

                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    components.second = 0

                    let identifier = "prayer.\(prayer.rawValue).\(offset.anchor.rawValue).\(offset.minutes).\(dayOffset)"
                    let request = UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )
                    center.add(request) { error in
                        if let error {
                            Task { @MainActor in self.lastError = error.localizedDescription }
                        }
                    }
                }

                // Iqamah / jamaat reminder, when configured.
                if let iqamah = reminder.iqamahMinutes ?? settings.defaultIqamahMinutes, iqamah > 0 {
                    let fireDate = prayerTime.addingTimeInterval(Double(iqamah) * 60)
                    guard fireDate > date else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "\(prayer.displayName) jamaat"
                    content.body = "Iqamah in progress."
                    content.sound = .default
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    components.second = 0
                    let request = UNNotificationRequest(
                        identifier: "prayer.\(prayer.rawValue).iqamah.\(dayOffset)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )
                    center.add(request, withCompletionHandler: nil)
                }
            }
        }
    }

    private func notificationTitle(prayer: Prayer, offset: ReminderOffset) -> String {
        switch offset.anchor {
        case .at: return "\(prayer.displayName) time"
        case .before: return "\(prayer.displayName) in \(offset.minutes) min"
        case .after: return "\(prayer.displayName) was \(offset.minutes) min ago"
        }
    }

    private func bodyText(prayer: Prayer, offset: ReminderOffset, time: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm"
        let clock = formatter.string(from: time)
        switch offset.anchor {
        case .at: return "It is time for \(prayer.displayName)."
        case .before: return "\(prayer.displayName) begins at \(clock)."
        case .after: return "\(prayer.displayName) began at \(clock)."
        }
    }

    /// Post a notification immediately, so the user can verify their setup.
    func sendSample() async {
        if authorizationStatus != .authorized && authorizationStatus != .provisional {
            await requestAuthorization()
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            lastError = "Notifications are not allowed. Turn them on in System Settings › Notifications › Sajda Time."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Fajr time"
        content.body = "This is what a prayer reminder looks like."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Play one of the macOS alert sounds. Used for the in-app chime, because
    /// notification sounds must live in the app bundle.
    func playSound(named name: String) {
        guard let sound = NSSound(named: name) else { return }
        sound.play()
    }

    /// Play a user-chosen audio file (a full adhan recording, typically).
    func playAudioFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard let sound = NSSound(contentsOf: url, byReference: true) else { return }
        sound.play()
    }
}
