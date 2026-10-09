import Foundation

/// How clock times are written throughout the app.
public enum ClockFormat: String, Codable, CaseIterable, Sendable {
    case twelveHour
    case twentyFourHour

    public var displayName: String {
        switch self {
        case .twelveHour: return "12-hour"
        case .twentyFourHour: return "24-hour"
        }
    }

    /// Short sample so the setting is unambiguous in the UI.
    public var example: String {
        switch self {
        case .twelveHour: return "5:24 PM"
        case .twentyFourHour: return "17:24"
        }
    }

    public var uses24Hour: Bool { self == .twentyFourHour }
}

/// All time and date formatting goes through here so the 12/24-hour preference
/// applies everywhere at once, including the menu bar.
public enum TimeFormatting {

    /// Pattern used for clock times.
    public static func clockPattern(_ format: ClockFormat, withSeconds: Bool = false) -> String {
        switch (format, withSeconds) {
        case (.twelveHour, false): return "h:mm a"
        case (.twelveHour, true): return "h:mm:ss a"
        case (.twentyFourHour, false): return "HH:mm"
        case (.twentyFourHour, true): return "HH:mm:ss"
        }
    }

    /// "5:24 PM" or "17:24".
    public static func clock(
        _ date: Date,
        timeZone: TimeZone,
        format: ClockFormat,
        withSeconds: Bool = false
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = clockPattern(format, withSeconds: withSeconds)
        return formatter.string(from: date)
    }

    /// A start–end pair with the meridiem written once when both ends share it:
    /// "5:24 – 6:43 AM", "11:30 AM – 1:15 PM", or "05:24 – 06:43".
    public static func clockRange(
        _ start: Date,
        _ end: Date,
        timeZone: TimeZone,
        format: ClockFormat
    ) -> String {
        let startClock = clock(start, timeZone: timeZone, format: format)
        let endClock = clock(end, timeZone: timeZone, format: format)
        guard !format.uses24Hour else { return "\(startClock) – \(endClock)" }

        for period in [" AM", " PM"] where startClock.hasSuffix(period) && endClock.hasSuffix(period) {
            return startClock.replacingOccurrences(of: period, with: "") + " – " + endClock
        }
        return "\(startClock) – \(endClock)"
    }

    /// "Wednesday, 22 January 2025".
    public static func longDate(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Short duration for a countdown, e.g. "1:24:18" or "25m".
    public static func countdown(_ interval: TimeInterval, style: CountdownStyle = .clock) -> String {
        let total = max(0, Int(interval.rounded()))
        switch style {
        case .clock:
            return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        case .compact:
            let minutes = total / 60
            if minutes < 1 { return "<1m" }
            if minutes < 60 { return "\(minutes)m" }
            let hours = minutes / 60
            let rest = minutes % 60
            return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        }
    }

    public enum CountdownStyle: Sendable {
        /// "01:24:18"
        case clock
        /// "1h 24m"
        case compact
    }

    /// Duration of a prayer window, e.g. "1h 15m".
    public static func duration(_ interval: TimeInterval) -> String {
        countdown(interval, style: .compact)
    }
}
