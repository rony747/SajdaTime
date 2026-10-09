import Foundation

/// Juristic preference for Asr: Hanafi uses a shadow factor of 2, the majority use 1.
public enum Madhab: String, CaseIterable, Codable, Sendable, Identifiable {
    case standard
    case hanafi

    public var id: String { rawValue }

    public var asrShadowFactor: Double {
        switch self {
        case .standard: return 1
        case .hanafi: return 2
        }
    }

    public var displayName: String {
        switch self {
        case .standard: return "Standard (Shafi'i, Maliki, Hanbali)"
        case .hanafi: return "Hanafi"
        }
    }

    /// Aladhan expects `school=0` for standard and `school=1` for Hanafi.
    public var aladhanValue: Int { self == .hanafi ? 1 : 0 }
}

/// How to behave at high latitudes where the sun may not dip far enough below
/// the horizon for Fajr/Isha to occur at all.
public enum HighLatitudeRule: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic
    case middleOfNight
    case oneSeventh
    case angleBased
    case none

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: return "Automatic (angle based)"
        case .middleOfNight: return "Middle of the night"
        case .oneSeventh: return "One seventh of the night"
        case .angleBased: return "Angle based"
        case .none: return "None"
        }
    }

    /// Aladhan's `latitudeAdjustmentMethod`: 1 = middle of night, 2 = one seventh, 3 = angle based.
    public var aladhanValue: Int? {
        switch self {
        case .automatic, .none: return nil
        case .middleOfNight: return 1
        case .oneSeventh: return 2
        case .angleBased: return 3
        }
    }
}

/// A prayer time calculation convention: the solar angles (or fixed intervals)
/// that define Fajr and Isha, plus any per-prayer tuning in minutes.
public struct CalculationMethod: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    /// Degrees below the horizon for Fajr.
    public let fajrAngle: Double
    /// Degrees below the horizon for Isha. Ignored when `ishaInterval` is set.
    public let ishaAngle: Double
    /// Fixed minutes after Maghrib for Isha (Umm al-Qura, Gulf, Qatar).
    public let ishaInterval: Double?
    /// Degrees below the horizon for Maghrib (Ja'fari / Tehran).
    public let maghribAngle: Double?
    /// Fixed minutes after sunset for Maghrib (Portugal, Jordan).
    public let maghribInterval: Double?
    /// Per-prayer tuning in minutes, added to the calculated time.
    public let adjustments: [String: Double]
    /// Aladhan method id, used when fetching from the API.
    public let aladhanId: Int
    /// Ja'fari/Tehran measure the night to Fajr rather than to sunrise for the
    /// purpose of Islamic midnight.
    public let midnightFromFajr: Bool

    public init(
        id: String,
        name: String,
        fajrAngle: Double,
        ishaAngle: Double = 0,
        ishaInterval: Double? = nil,
        maghribAngle: Double? = nil,
        maghribInterval: Double? = nil,
        adjustments: [String: Double] = [:],
        aladhanId: Int,
        midnightFromFajr: Bool = false
    ) {
        self.id = id
        self.name = name
        self.fajrAngle = fajrAngle
        self.ishaAngle = ishaAngle
        self.ishaInterval = ishaInterval
        self.maghribAngle = maghribAngle
        self.maghribInterval = maghribInterval
        self.adjustments = adjustments
        self.aladhanId = aladhanId
        self.midnightFromFajr = midnightFromFajr
    }

    public func adjustment(for prayer: Prayer) -> Double {
        adjustments[prayer.rawValue] ?? 0
    }
}

public extension CalculationMethod {
    /// The method catalogue, mirroring Aladhan's `method` ids so that the
    /// offline calculator and the API agree when the user switches sources.
    static let all: [CalculationMethod] = [
        CalculationMethod(id: "MWL", name: "Muslim World League", fajrAngle: 18, ishaAngle: 17, aladhanId: 3),
        CalculationMethod(id: "ISNA", name: "Islamic Society of North America (ISNA)", fajrAngle: 15, ishaAngle: 15, aladhanId: 2),
        CalculationMethod(id: "EGYPT", name: "Egyptian General Authority of Survey", fajrAngle: 19.5, ishaAngle: 17.5, aladhanId: 5),
        CalculationMethod(id: "MAKKAH", name: "Umm Al-Qura University, Makkah", fajrAngle: 18.5, ishaInterval: 90, aladhanId: 4),
        CalculationMethod(id: "KARACHI", name: "University of Islamic Sciences, Karachi", fajrAngle: 18, ishaAngle: 18, aladhanId: 1),
        CalculationMethod(id: "TEHRAN", name: "Institute of Geophysics, University of Tehran", fajrAngle: 17.7, ishaAngle: 14, maghribAngle: 4.5, aladhanId: 7, midnightFromFajr: true),
        CalculationMethod(id: "JAFARI", name: "Shia Ithna-Ashari, Leva Institute, Qum", fajrAngle: 16, ishaAngle: 14, maghribAngle: 4, aladhanId: 0, midnightFromFajr: true),
        CalculationMethod(id: "GULF", name: "Gulf Region", fajrAngle: 19.5, ishaInterval: 90, aladhanId: 8),
        CalculationMethod(id: "KUWAIT", name: "Kuwait", fajrAngle: 18, ishaAngle: 17.5, aladhanId: 9),
        CalculationMethod(id: "QATAR", name: "Qatar", fajrAngle: 18, ishaInterval: 90, aladhanId: 10),
        CalculationMethod(id: "SINGAPORE", name: "Majlis Ugama Islam Singapura, Singapore", fajrAngle: 20, ishaAngle: 18, aladhanId: 11),
        CalculationMethod(id: "FRANCE", name: "Union Organization Islamic de France", fajrAngle: 12, ishaAngle: 12, aladhanId: 12),
        CalculationMethod(id: "TURKEY", name: "Diyanet İşleri Başkanlığı, Turkey", fajrAngle: 18, ishaAngle: 17, adjustments: ["sunrise": -7, "dhuhr": 5, "asr": 4, "maghrib": 7], aladhanId: 13),
        CalculationMethod(id: "RUSSIA", name: "Spiritual Administration of Muslims of Russia", fajrAngle: 16, ishaAngle: 15, aladhanId: 14),
        // Moonsighting Committee Worldwide is deliberately absent: its Fajr/Isha
        // use a seasonal correction table that this engine does not implement,
        // and shipping it would produce times 15-30 minutes out.
        CalculationMethod(id: "DUBAI", name: "Dubai", fajrAngle: 18.2, ishaAngle: 18.2, adjustments: ["dhuhr": 3, "maghrib": 3], aladhanId: 16),
        CalculationMethod(id: "JAKIM", name: "Jabatan Kemajuan Islam Malaysia (JAKIM)", fajrAngle: 20, ishaAngle: 18, aladhanId: 17),
        CalculationMethod(id: "TUNISIA", name: "Tunisia", fajrAngle: 18, ishaAngle: 18, aladhanId: 18),
        CalculationMethod(id: "ALGERIA", name: "Algeria", fajrAngle: 18, ishaAngle: 17, aladhanId: 19),
        CalculationMethod(id: "KEMENAG", name: "Kementerian Agama Republik Indonesia", fajrAngle: 20, ishaAngle: 18, aladhanId: 20),
        CalculationMethod(id: "MOROCCO", name: "Morocco", fajrAngle: 19, ishaAngle: 17, adjustments: ["dhuhr": 5, "maghrib": 5], aladhanId: 21),
        // Comunidade Islamica de Lisboa and the Jordanian ministry both define
        // Maghrib as a fixed interval after sunset, and Lisbon defines Isha as a
        // fixed interval after Maghrib rather than a solar angle.
        CalculationMethod(id: "PORTUGAL", name: "Comunidade Islamica de Lisboa", fajrAngle: 18, ishaInterval: 77, maghribInterval: 3, adjustments: ["dhuhr": 5], aladhanId: 22),
        CalculationMethod(id: "JORDAN", name: "Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan", fajrAngle: 18, ishaAngle: 18, maghribInterval: 5, aladhanId: 23),
    ]

    static func method(id: String) -> CalculationMethod {
        all.first { $0.id == id } ?? all.first { $0.id == "MWL" }!
    }

    /// Best-guess method for a country, used by "Auto-detect method from location".
    static func autoDetected(forCountryCode code: String) -> CalculationMethod {
        switch code.uppercased() {
        case "SA", "YE": return method(id: "MAKKAH")
        case "AE": return method(id: "DUBAI")
        case "KW": return method(id: "KUWAIT")
        case "QA": return method(id: "QATAR")
        case "BH", "OM": return method(id: "GULF")
        case "EG": return method(id: "EGYPT")
        case "PK", "IN", "BD", "AF", "LK", "NP": return method(id: "KARACHI")
        case "TR": return method(id: "TURKEY")
        case "IR": return method(id: "TEHRAN")
        case "US", "CA", "MX": return method(id: "ISNA")
        case "GB", "IE": return method(id: "MWL")
        case "FR": return method(id: "FRANCE")
        case "MY": return method(id: "JAKIM")
        case "ID": return method(id: "KEMENAG")
        case "SG": return method(id: "SINGAPORE")
        case "MA": return method(id: "MOROCCO")
        case "DZ": return method(id: "ALGERIA")
        case "TN": return method(id: "TUNISIA")
        case "JO": return method(id: "JORDAN")
        case "PT": return method(id: "PORTUGAL")
        case "RU", "KZ", "UZ", "TJ", "KG", "AZ": return method(id: "RUSSIA")
        default: return method(id: "MWL")
        }
    }
}
