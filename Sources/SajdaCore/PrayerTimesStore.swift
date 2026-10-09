import Foundation

/// Decides where a day's prayer times come from.
///
/// Order of preference:
///   1. Manually fixed times, when the user has chosen that mode.
///   2. A cached day fetched earlier from Aladhan.
///   3. A fresh Aladhan fetch.
///   4. On-device calculation, if the network is unavailable.
///
/// The result always records which path was taken, and that is shown in the UI.
public struct PrayerTimesStore: Sendable {
    private let client: AladhanClient
    private let cache: PrayerTimesCache

    public init(client: AladhanClient = AladhanClient(), cache: PrayerTimesCache = PrayerTimesCache()) {
        self.client = client
        self.cache = cache
    }

    public func times(for settings: AppSettings, date: Date = Date()) async -> PrayerTimes {
        let zone = settings.displayTimeZone

        if settings.timeSourceMode == .manual {
            return Self.manualTimes(settings: settings, date: date, timeZone: zone)
        }

        let key = PrayerTimesCache.key(settings: settings, date: date, timeZone: zone)

        if settings.fetchLiveTimes {
            if var cached = cache.load(key: key) {
                cached.source = .cache
                return cached
            }
            do {
                let fetched = try await client.fetchTimes(
                    date: date,
                    coordinate: settings.coordinate,
                    timeZone: zone,
                    method: settings.method,
                    madhab: settings.madhab,
                    highLatitudeRule: settings.highLatitudeRule,
                    // Only the user's own tuning is sent; Aladhan already applies
                    // whatever the chosen method specifies internally.
                    adjustments: settings.userAdjustments,
                    hijriAdjustment: settings.hijriDayAdjustment
                )
                cache.save(fetched, key: key)
                return fetched
            } catch {
                // Fall through to the on-device calculation.
            }
        }

        return PrayerCalculator.calculate(
            date: date,
            coordinate: settings.coordinate,
            timeZone: zone,
            options: settings.calculationOptions
        )
    }

    /// Build a day from fixed times the user typed, e.g. "05:38".
    static func manualTimes(settings: AppSettings, date: Date, timeZone: TimeZone) -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)

        var times: [Prayer: Date] = [:]
        for prayer in Prayer.allCases {
            guard let raw = settings.manualTimes[prayer.rawValue],
                  let clock = AladhanClient.parseClock(raw) else { continue }
            var components = DateComponents()
            components.year = calendar.component(.year, from: dayStart)
            components.month = calendar.component(.month, from: dayStart)
            components.day = calendar.component(.day, from: dayStart)
            components.hour = clock.hour
            components.minute = clock.minute
            if let value = calendar.date(from: components) {
                times[prayer] = value
            }
        }

        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.timeZone = timeZone

        return PrayerTimes(
            dayStart: dayStart,
            times: times,
            source: .calculated,
            methodName: "Fixed times",
            timeZoneIdentifier: timeZone.identifier,
            coordinate: settings.coordinate,
            hijri: HijriDate(from: dayStart, calendar: hijriCalendar, adjustment: settings.hijriDayAdjustment)
        )
    }
}
