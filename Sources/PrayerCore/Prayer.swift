import Foundation

/// The five daily obligatory prayers plus sunrise, which is shown in the list
/// but is not itself a prayer.
public enum Prayer: String, CaseIterable, Codable, Sendable, Identifiable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    public var id: String { rawValue }

    /// Prayers that carry an adhan and can be notified on.
    public static let obligatory: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    public var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    /// SF Symbol names, chosen to match the reference app's iconography.
    public var symbolName: String {
        switch self {
        case .fajr: return "sunrise.fill"
        case .sunrise: return "sunrise"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "cloud.sun.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }

    /// Is this prayer one that a user can be notified about?
    public var isNotifiable: Bool { self != .sunrise }
}
