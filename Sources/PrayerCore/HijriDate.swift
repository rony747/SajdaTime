import Foundation

/// A Hijri (Umm al-Qura) calendar date with a user-adjustable day offset, which
/// is how local moon-sighting differences are usually reconciled.
public struct HijriDate: Codable, Sendable, Equatable {
    public var day: Int
    public var monthIndex: Int   // 1...12
    public var year: Int
    /// The offset that was applied when producing this value, in days.
    public var adjustment: Int

    public init(day: Int, monthIndex: Int, year: Int, adjustment: Int = 0) {
        self.day = day
        self.monthIndex = monthIndex
        self.year = year
        self.adjustment = adjustment
    }

    public init?(from date: Date, calendar: Calendar, adjustment: Int) {
        guard let shifted = calendar.date(byAdding: .day, value: adjustment, to: date) else { return nil }
        let components = calendar.dateComponents([.day, .month, .year], from: shifted)
        guard let day = components.day, let month = components.month, let year = components.year else { return nil }
        self.day = day
        self.monthIndex = month
        self.year = year
        self.adjustment = adjustment
    }

    /// English month names in the order Foundation's Umm al-Qura calendar uses.
    public static let monthNames: [String] = [
        "Muharram", "Safar", "Rabi' I", "Rabi' II", "Jumada I", "Jumada II",
        "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah",
    ]

    public var monthName: String {
        guard monthIndex >= 1, monthIndex <= Self.monthNames.count else { return "" }
        return Self.monthNames[monthIndex - 1]
    }

    /// e.g. "28 Rabi' II 1448 AH"
    public var formatted: String {
        "\(day) \(monthName) \(year) AH"
    }

    /// Umm al-Qura numbering, used when talking to the Aladhan API.
    public var numeric: String {
        String(format: "%02d-%02d-%04d", day, monthIndex, year)
    }
}
