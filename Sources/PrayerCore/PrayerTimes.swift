import Foundation

/// A geographic position. Deliberately framework-free so `PrayerCore` stays testable.
public struct Coordinate: Codable, Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// How a day's times were obtained, surfaced in the UI so the user always knows
/// whether they are looking at fetched or locally computed data.
public enum PrayerTimeSource: String, Codable, Sendable {
    case api        // fetched from Aladhan
    case cache      // fetched earlier and stored on disk
    case calculated // computed on-device

    public var label: String {
        switch self {
        case .api: return "Live from Aladhan"
        case .cache: return "Cached from Aladhan"
        case .calculated: return "Calculated on device"
        }
    }
}

/// The interval during which a prayer may validly be performed.
///
/// This is not simply "until the next prayer starts". Fajr's time ends at
/// sunrise, roughly an hour after it begins, not at Dhuhr. Isha's chosen time
/// ends at Islamic midnight; the stretch from midnight to Fajr is the time of
/// necessity (darurah), carried separately in `necessityEnd`.
public struct PrayerWindow: Sendable, Equatable {
    public let prayer: Prayer
    /// When the prayer's time begins.
    public let start: Date
    /// End of the valid (chosen) time.
    public let end: Date
    /// What ends the window, for display: "sunrise", "Asr", "Islamic midnight".
    public let endLabel: String
    /// For Isha only: Fajr, after which the prayer is no longer valid at all.
    public let necessityEnd: Date?

    public init(prayer: Prayer, start: Date, end: Date, endLabel: String, necessityEnd: Date? = nil) {
        self.prayer = prayer
        self.start = start
        self.end = end
        self.endLabel = endLabel
        self.necessityEnd = necessityEnd
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func remaining(at date: Date) -> TimeInterval { end.timeIntervalSince(date) }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }
}

/// One day of prayer times, resolved to absolute instants.
public struct PrayerTimes: Codable, Sendable, Equatable {
    /// Midnight at the start of the day, in the display timezone.
    public var dayStart: Date
    /// Absolute instants for each prayer. Sunrise is included.
    public var times: [Prayer: Date]
    /// Islamic midnight and the last third of the night, when computable.
    public var midnight: Date?
    public var lastThird: Date?
    public var source: PrayerTimeSource
    /// Name of the calculation method actually used (API may report its own).
    public var methodName: String
    public var timeZoneIdentifier: String
    /// Latitude/longitude these times belong to.
    public var coordinate: Coordinate
    /// Hijri date, when known.
    public var hijri: HijriDate?
    /// True when this location had no sunrise or sunset on this date (polar day
    /// or night) and a mid-latitude reference was substituted for the
    /// angle-based times. Surfaced in the UI so the value is never silently wrong.
    public var usedPolarFallback: Bool

    public init(
        dayStart: Date,
        times: [Prayer: Date],
        midnight: Date? = nil,
        lastThird: Date? = nil,
        source: PrayerTimeSource,
        methodName: String,
        timeZoneIdentifier: String,
        coordinate: Coordinate,
        hijri: HijriDate? = nil,
        usedPolarFallback: Bool = false
    ) {
        self.dayStart = dayStart
        self.times = times
        self.midnight = midnight
        self.lastThird = lastThird
        self.source = source
        self.methodName = methodName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.coordinate = coordinate
        self.hijri = hijri
        self.usedPolarFallback = usedPolarFallback
    }

    public func time(for prayer: Prayer) -> Date? { times[prayer] }

    /// Prayers in chronological order for display, including sunrise.
    public var ordered: [(prayer: Prayer, date: Date)] {
        Prayer.allCases
            .compactMap { prayer in times[prayer].map { (prayer, $0) } }
            .sorted { $0.1 < $1.1 }
    }

    /// The next prayer strictly after `date`, looking only within this day.
    public func nextPrayer(after date: Date, includingSunrise: Bool = true) -> (prayer: Prayer, date: Date)? {
        ordered.first { entry in
            entry.date > date && (includingSunrise || entry.prayer != .sunrise)
        }
    }

    /// The prayer whose window is currently open.
    public func currentPrayer(at date: Date, includingSunrise: Bool = false) -> (prayer: Prayer, date: Date)? {
        ordered.last { entry in
            entry.date <= date && (includingSunrise || entry.prayer != .sunrise)
        }
    }

    // MARK: - Prayer windows

    /// The valid time interval for one prayer.
    ///
    /// - Parameter nextDay: tomorrow's times, needed for Isha because its window
    ///   runs past midnight, and as a fallback when no Islamic midnight is known.
    public func window(for prayer: Prayer, nextDay: PrayerTimes? = nil) -> PrayerWindow? {
        switch prayer {
        case .sunrise:
            return nil

        case .fajr:
            // Dawn until sunrise. This is why Fajr's remaining time is short.
            guard let start = times[.fajr], let end = times[.sunrise] else { return nil }
            return PrayerWindow(prayer: .fajr, start: start, end: end, endLabel: "sunrise")

        case .dhuhr:
            guard let start = times[.dhuhr], let end = times[.asr] else { return nil }
            return PrayerWindow(prayer: .dhuhr, start: start, end: end, endLabel: "Asr")

        case .asr:
            guard let start = times[.asr], let end = times[.maghrib] else { return nil }
            return PrayerWindow(prayer: .asr, start: start, end: end, endLabel: "Maghrib")

        case .maghrib:
            guard let start = times[.maghrib], let end = times[.isha] else { return nil }
            return PrayerWindow(prayer: .maghrib, start: start, end: end, endLabel: "Isha")

        case .isha:
            guard let start = times[.isha] else { return nil }
            // Chosen time ends at Islamic midnight; midnight to Fajr is the time
            // of necessity, so both bounds are reported.
            guard let end = midnight ?? nextDay?.times[.fajr] else { return nil }
            return PrayerWindow(
                prayer: .isha,
                start: start,
                end: end,
                endLabel: midnight != nil ? "Islamic midnight" : "Fajr",
                necessityEnd: nextDay?.times[.fajr]
            )
        }
    }

    /// All windows for obligatory prayers, in day order.
    public func windows(nextDay: PrayerTimes? = nil) -> [PrayerWindow] {
        Prayer.obligatory.compactMap { window(for: $0, nextDay: nextDay) }
    }

    /// The window open at `date`, if any.
    ///
    /// Returns nil between sunrise and Dhuhr, and between Islamic midnight and
    /// Fajr: in those gaps no obligatory prayer is currently in its chosen time.
    /// `previousDay` is needed because yesterday's Isha window runs past midnight.
    public func activeWindow(
        at date: Date,
        previousDay: PrayerTimes? = nil,
        nextDay: PrayerTimes? = nil
    ) -> PrayerWindow? {
        for prayer in Prayer.obligatory {
            if let window = window(for: prayer, nextDay: nextDay), window.contains(date) {
                return window
            }
        }
        // Yesterday's Isha can still be open in the early hours of today.
        if let previousDay,
           let isha = previousDay.window(for: .isha, nextDay: self),
           isha.contains(date) {
            return isha
        }
        return nil
    }
}

// MARK: - Persistence
//
// `times` is written with string keys rather than relying on the synthesised
// encoding for a dictionary with an enum key type. The synthesised form is an
// order-dependent array, which would silently mis-decode if `Prayer.allCases`
// were ever reordered.
extension PrayerTimes {

    enum CodingKeys: String, CodingKey {
        case dayStart, times, midnight, lastThird, source
        case methodName, timeZoneIdentifier, coordinate, hijri, usedPolarFallback
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayStart = try container.decode(Date.self, forKey: .dayStart)

        let rawTimes = (try? container.decode([String: Date].self, forKey: .times)) ?? [:]
        var mapped: [Prayer: Date] = [:]
        for (key, value) in rawTimes {
            if let prayer = Prayer(rawValue: key) { mapped[prayer] = value }
        }
        times = mapped

        midnight = try container.decodeIfPresent(Date.self, forKey: .midnight)
        lastThird = try container.decodeIfPresent(Date.self, forKey: .lastThird)
        source = try container.decode(PrayerTimeSource.self, forKey: .source)
        methodName = try container.decode(String.self, forKey: .methodName)
        timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
        coordinate = try container.decode(Coordinate.self, forKey: .coordinate)
        hijri = try container.decodeIfPresent(HijriDate.self, forKey: .hijri)
        usedPolarFallback = try container.decodeIfPresent(Bool.self, forKey: .usedPolarFallback) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayStart, forKey: .dayStart)

        var rawTimes: [String: Date] = [:]
        for (prayer, date) in times { rawTimes[prayer.rawValue] = date }
        try container.encode(rawTimes, forKey: .times)

        try container.encodeIfPresent(midnight, forKey: .midnight)
        try container.encodeIfPresent(lastThird, forKey: .lastThird)
        try container.encode(source, forKey: .source)
        try container.encode(methodName, forKey: .methodName)
        try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encodeIfPresent(hijri, forKey: .hijri)
        try container.encode(usedPolarFallback, forKey: .usedPolarFallback)
    }
}
