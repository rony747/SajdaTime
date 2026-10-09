import Foundation

// MARK: - Supporting preferences

/// How the app decides where the user is.
public enum LocationMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case manual

    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual: return "Manual"
        }
    }
}

/// Whether times are derived from the location, or fixed values the user typed.
public enum TimeSourceMode: String, Codable, CaseIterable, Sendable {
    case astronomical
    case manual

    public var displayName: String {
        switch self {
        case .astronomical: return "Calculated"
        case .manual: return "Manual (fixed)"
        }
    }
}

public enum TimeZoneMode: String, Codable, CaseIterable, Sendable {
    case followSystem
    case explicit

    public var displayName: String {
        switch self {
        case .followSystem: return "Follow system"
        case .explicit: return "Pick explicitly"
        }
    }
}

/// What the menu bar countdown counts down to.
public enum CountdownTarget: String, Codable, CaseIterable, Sendable {
    /// Time left in the prayer you can currently perform, ending at that
    /// prayer's own boundary (Fajr ends at sunrise, not at Dhuhr).
    case currentWindowEnd
    /// Time until the next prayer begins.
    case nextPrayer

    public var displayName: String {
        switch self {
        case .nextPrayer: return "Time until the next prayer"
        case .currentWindowEnd: return "Time left in the current prayer"
        }
    }
}

/// How much of the label is shown next to the menu bar icon.
public enum MenuBarLabelStyle: String, Codable, CaseIterable, Sendable {
    case iconOnly
    case name
    case countdown
    case iconName
    case iconCountdown
    case nameCountdown
    case iconNameCountdown

    public var displayName: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .name: return "Name only"
        case .countdown: return "Countdown only"
        case .iconName: return "Icon + name"
        case .iconCountdown: return "Icon + countdown"
        case .nameCountdown: return "Name + countdown"
        case .iconNameCountdown: return "Icon + name + countdown"
        }
    }

    public var showsIcon: Bool {
        switch self {
        case .iconOnly, .iconName, .iconCountdown, .iconNameCountdown: return true
        default: return false
        }
    }

    public var showsName: Bool {
        switch self {
        case .name, .iconName, .nameCountdown, .iconNameCountdown: return true
        default: return false
        }
    }

    public var showsCountdown: Bool {
        switch self {
        case .countdown, .iconCountdown, .nameCountdown, .iconNameCountdown: return true
        default: return false
        }
    }
}

/// Whether a prayer uses the app's default reminder timing or the user's.
public enum ReminderMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case manual
    case off

    public var displayName: String {
        switch self {
        case .automatic: return "Auto"
        case .manual: return "Manual"
        case .off: return "Off"
        }
    }
}

/// One reminder relative to a prayer time, e.g. 10 minutes before.
public struct ReminderOffset: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Anchor: String, Codable, CaseIterable, Sendable {
        case before
        case at
        case after

        public var displayName: String {
            switch self {
            case .before: return "before"
            case .at: return "at"
            case .after: return "after"
            }
        }
    }

    public var anchor: Anchor
    public var minutes: Int

    public var id: String { "\(anchor.rawValue)-\(minutes)" }

    public init(anchor: Anchor, minutes: Int) {
        self.anchor = anchor
        self.minutes = minutes
    }

    /// Offset in seconds relative to the prayer time; negative means earlier.
    public var secondsFromPrayer: TimeInterval {
        switch anchor {
        case .before: return -Double(minutes) * 60
        case .at: return 0
        case .after: return Double(minutes) * 60
        }
    }

    public var shortDescription: String {
        switch anchor {
        case .at: return "At time"
        case .before: return "\(minutes) min before"
        case .after: return "\(minutes) min after"
        }
    }
}

/// Per-prayer notification preferences.
public struct PrayerReminderSettings: Codable, Equatable, Sendable {
    public var mode: ReminderMode
    /// Used when `mode == .manual`.
    public var offsets: [ReminderOffset]
    /// Whether the adhan audio plays at the prayer time itself.
    public var playAdhan: Bool
    /// Overrides the default sound when set.
    public var soundName: String?
    /// Iqamah / jamaat offset in minutes after the prayer time.
    public var iqamahMinutes: Int?

    public init(
        mode: ReminderMode = .automatic,
        offsets: [ReminderOffset] = [ReminderOffset(anchor: .at, minutes: 0)],
        playAdhan: Bool = false,
        soundName: String? = nil,
        iqamahMinutes: Int? = nil
    ) {
        self.mode = mode
        self.offsets = offsets
        self.playAdhan = playAdhan
        self.soundName = soundName
        self.iqamahMinutes = iqamahMinutes
    }

    /// The offsets that should actually be scheduled.
    public func effectiveOffsets(defaults: [ReminderOffset]) -> [ReminderOffset] {
        switch mode {
        case .off: return []
        case .automatic: return defaults
        case .manual: return offsets
        }
    }
}

public enum BlurIntensity: String, Codable, CaseIterable, Sendable {
    case light
    case medium
    case heavy

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

public enum FocusTrigger: String, Codable, CaseIterable, Sendable {
    case obligatoryPrayers
    case allPrayers
    case fajrAndIsha

    public var displayName: String {
        switch self {
        case .obligatoryPrayers: return "Obligatory prayers"
        case .allPrayers: return "All prayers"
        case .fajrAndIsha: return "Fajr and Isha"
        }
    }

    public func includes(_ prayer: Prayer) -> Bool {
        switch self {
        case .obligatoryPrayers: return Prayer.obligatory.contains(prayer)
        case .allPrayers: return Prayer.obligatory.contains(prayer)
        case .fajrAndIsha: return prayer == .fajr || prayer == .isha
        }
    }
}

// MARK: - Settings

/// Everything the user can configure. Pure data so it can be persisted,
/// diffed and tested without a UI.
public struct AppSettings: Codable, Equatable, Sendable {

    // Location
    public var locationMode: LocationMode
    public var latitude: Double
    public var longitude: Double
    public var elevation: Double
    public var locationName: String
    public var countryCode: String
    /// True while the coordinates came from the system timezone rather than a
    /// real fix or an explicit choice, so the UI can say so and offer to refine.
    public var locationIsEstimated: Bool

    // Timezone
    public var timeZoneMode: TimeZoneMode
    public var explicitTimeZoneID: String

    // Calculation
    public var timeSourceMode: TimeSourceMode
    public var methodID: String
    public var madhab: Madhab
    public var highLatitudeRule: HighLatitudeRule
    public var autoDetectMethod: Bool
    /// Per-prayer tuning in minutes, applied on top of the method.
    public var userAdjustments: [String: Double]
    /// Fixed times (HH:mm) used when `timeSourceMode == .manual`.
    public var manualTimes: [String: String]
    /// Whether to fetch live times from Aladhan, falling back to local calculation.
    public var fetchLiveTimes: Bool
    public var hijriDayAdjustment: Int

    // General
    public var launchAtLogin: Bool
    public var menuBarLabelStyle: MenuBarLabelStyle
    public var countdownTarget: CountdownTarget
    public var showIshraq: Bool
    public var showHijriDate: Bool
    /// 12-hour ("5:24 PM") or 24-hour ("17:24") clocks.
    public var clockFormat: ClockFormat
    /// Light, dark, or follow the system.
    public var appearance: AppAppearance

    // Notifications
    public var notificationsEnabled: Bool
    public var defaultSoundName: String
    public var playFullAdhan: Bool
    public var defaultEarlyReminderMinutes: Int?
    public var defaultIqamahMinutes: Int?
    /// Path to the audio file played for the full adhan, when the user opts in.
    public var adhanAudioPath: String?
    /// Show a full-screen reminder at prayer time, rather than only a banner.
    public var fullScreenReminder: Bool
    /// How long the reminder's snooze defers it, in minutes.
    public var snoozeMinutes: Int
    /// Minutes before the reminder closes itself. 0 leaves it up until dismissed.
    public var alertAutoCloseMinutes: Int
    public var perPrayer: [String: PrayerReminderSettings]

    // Focus mode
    public var focusModeEnabled: Bool
    public var focusDurationMinutes: Int
    public var focusBlurIntensity: BlurIntensity
    public var focusTrigger: FocusTrigger
    public var focusEmergencyExit: Bool

    public init(
        locationMode: LocationMode = .automatic,
        // Placeholder only; `fresh(for:)` seeds these from the system timezone
        // so the app never silently shows another city's times.
        latitude: Double = 0,
        longitude: Double = 0,
        elevation: Double = 0,
        locationName: String = "",
        countryCode: String = "",
        locationIsEstimated: Bool = true,
        timeZoneMode: TimeZoneMode = .followSystem,
        explicitTimeZoneID: String = TimeZone.current.identifier,
        timeSourceMode: TimeSourceMode = .astronomical,
        methodID: String = "MWL",
        madhab: Madhab = .standard,
        highLatitudeRule: HighLatitudeRule = .automatic,
        autoDetectMethod: Bool = true,
        userAdjustments: [String: Double] = [:],
        manualTimes: [String: String] = [:],
        fetchLiveTimes: Bool = true,
        hijriDayAdjustment: Int = 0,
        launchAtLogin: Bool = false,
        menuBarLabelStyle: MenuBarLabelStyle = .iconNameCountdown,
        countdownTarget: CountdownTarget = .currentWindowEnd,
        showIshraq: Bool = false,
        showHijriDate: Bool = true,
        clockFormat: ClockFormat = .twelveHour,
        appearance: AppAppearance = .system,
        notificationsEnabled: Bool = true,
        defaultSoundName: String = "Soft chime",
        playFullAdhan: Bool = false,
        defaultEarlyReminderMinutes: Int? = nil,
        defaultIqamahMinutes: Int? = nil,
        adhanAudioPath: String? = nil,
        fullScreenReminder: Bool = true,
        snoozeMinutes: Int = 10,
        alertAutoCloseMinutes: Int = 15,
        perPrayer: [String: PrayerReminderSettings] = [:],
        focusModeEnabled: Bool = false,
        focusDurationMinutes: Int = 15,
        focusBlurIntensity: BlurIntensity = .medium,
        focusTrigger: FocusTrigger = .obligatoryPrayers,
        focusEmergencyExit: Bool = true
    ) {
        self.locationMode = locationMode
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.locationName = locationName
        self.countryCode = countryCode
        self.locationIsEstimated = locationIsEstimated
        self.timeZoneMode = timeZoneMode
        self.explicitTimeZoneID = explicitTimeZoneID
        self.timeSourceMode = timeSourceMode
        self.methodID = methodID
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.autoDetectMethod = autoDetectMethod
        self.userAdjustments = userAdjustments
        self.manualTimes = manualTimes
        self.fetchLiveTimes = fetchLiveTimes
        self.hijriDayAdjustment = hijriDayAdjustment
        self.launchAtLogin = launchAtLogin
        self.menuBarLabelStyle = menuBarLabelStyle
        self.countdownTarget = countdownTarget
        self.showIshraq = showIshraq
        self.showHijriDate = showHijriDate
        self.clockFormat = clockFormat
        self.appearance = appearance
        self.notificationsEnabled = notificationsEnabled
        self.defaultSoundName = defaultSoundName
        self.playFullAdhan = playFullAdhan
        self.defaultEarlyReminderMinutes = defaultEarlyReminderMinutes
        self.defaultIqamahMinutes = defaultIqamahMinutes
        self.adhanAudioPath = adhanAudioPath
        self.fullScreenReminder = fullScreenReminder
        self.snoozeMinutes = snoozeMinutes
        self.alertAutoCloseMinutes = alertAutoCloseMinutes
        self.perPrayer = perPrayer
        self.focusModeEnabled = focusModeEnabled
        self.focusDurationMinutes = focusDurationMinutes
        self.focusBlurIntensity = focusBlurIntensity
        self.focusTrigger = focusTrigger
        self.focusEmergencyExit = focusEmergencyExit
    }

    /// Settings for a first launch, seeded from the system timezone so the very
    /// first render is already in the right part of the world.
    ///
    /// Previously this defaulted to Istanbul, which showed Istanbul's prayer
    /// times — on the local clock — to everyone who had not set a location.
    public static func fresh(for timeZone: TimeZone) -> AppSettings {
        var settings = AppSettings()
        settings.timeZoneMode = .followSystem
        settings.explicitTimeZoneID = timeZone.identifier
        settings.locationMode = .automatic

        guard let place = TimeZonePlaces.place(forTimeZoneIdentifier: timeZone.identifier) else {
            // No representative city known: leave the position unset and let the
            // UI ask for it rather than invent one.
            settings.locationIsEstimated = true
            return settings
        }

        settings.latitude = place.latitude
        settings.longitude = place.longitude
        settings.locationName = place.city
        settings.countryCode = place.countryCode
        settings.locationIsEstimated = true
        if settings.autoDetectMethod {
            settings.methodID = CalculationMethod.autoDetected(forCountryCode: place.countryCode).id
        }
        return settings
    }

    /// True when we have no usable position at all.
    public var hasUsableLocation: Bool {
        !(latitude == 0 && longitude == 0)
    }

    // MARK: Derived values

    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    /// The timezone times are displayed and scheduled in.
    public var displayTimeZone: TimeZone {
        switch timeZoneMode {
        case .followSystem:
            return TimeZone.current
        case .explicit:
            return TimeZone(identifier: explicitTimeZoneID) ?? TimeZone.current
        }
    }

    public var method: CalculationMethod {
        CalculationMethod.method(id: methodID)
    }

    /// Reminder settings for a prayer, filling in defaults for anything unset.
    public func reminder(for prayer: Prayer) -> PrayerReminderSettings {
        perPrayer[prayer.rawValue] ?? PrayerReminderSettings()
    }

    /// The app-wide default reminder offsets, derived from the early-reminder
    /// preference, plus the prayer time itself.
    public var defaultOffsets: [ReminderOffset] {
        var offsets: [ReminderOffset] = []
        if let early = defaultEarlyReminderMinutes, early > 0 {
            offsets.append(ReminderOffset(anchor: .before, minutes: early))
        }
        offsets.append(ReminderOffset(anchor: .at, minutes: 0))
        return offsets
    }

    /// Format a clock time using the user's 12/24-hour preference.
    public func clock(_ date: Date, withSeconds: Bool = false) -> String {
        TimeFormatting.clock(date, timeZone: displayTimeZone, format: clockFormat, withSeconds: withSeconds)
    }

    public var calculationOptions: PrayerCalculator.Options {
        PrayerCalculator.Options(
            method: method,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            elevation: elevation,
            userAdjustments: userAdjustments,
            hijriAdjustment: hijriDayAdjustment
        )
    }
}
