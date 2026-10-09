import Foundation

/// Raw solar hours for one day, before timezone shifting or tuning.
private struct RawSolarDay {
    var hours: [Prayer: Double]
    var sunset: Double
}

/// On-device prayer time calculation.
///
/// This is the offline path: it produces the same numbers Aladhan returns when
/// both are configured identically, so the app keeps working with no network and
/// the "Calculated" mode is not a degraded experience.
public enum PrayerCalculator {

    /// Latitude used when the real one has no sunrise/sunset on this date.
    /// A mid-latitude reference keeps Fajr/Isha meaningful during polar day and
    /// polar night, instead of emitting nothing or collapsing every time onto
    /// the same minute.
    static let polarReferenceLatitude = 45.0

    public struct Options: Sendable {
        public var method: CalculationMethod
        public var madhab: Madhab
        public var highLatitudeRule: HighLatitudeRule
        /// Ground elevation in metres, used for the horizon dip.
        public var elevation: Double
        /// Extra per-prayer tuning in minutes, applied on top of the method.
        public var userAdjustments: [String: Double]

        public init(
            method: CalculationMethod,
            madhab: Madhab = .standard,
            highLatitudeRule: HighLatitudeRule = .automatic,
            elevation: Double = 0,
            userAdjustments: [String: Double] = [:]
        ) {
            self.method = method
            self.madhab = madhab
            self.highLatitudeRule = highLatitudeRule
            self.elevation = elevation
            self.userAdjustments = userAdjustments
        }
    }

    /// Calculate the times for the calendar day containing `date`, expressed on
    /// the wall clock of `timeZone`.
    public static func calculate(
        date: Date,
        coordinate: Coordinate,
        timeZone: TimeZone,
        options: Options
    ) -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dayStart = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1

        // The calculation works in wall-clock hours; the offset is the one in
        // force during this day, so DST transitions are handled per-day.
        let offsetHours = Double(timeZone.secondsFromGMT(for: dayStart)) / 3600.0

        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        // Longitude shifts the Julian day so that solar noon lands near 12:00.
        let jd = julianDay(year: year, month: month, day: day) - longitude / (15.0 * 24.0)

        // Horizon dip from elevation, plus standard refraction.
        let riseSetAngle = 0.833 + 0.0347 * sqrt(max(0, options.elevation))

        var raw = rawSolarDay(
            jd: jd, latitude: latitude, method: options.method,
            madhab: options.madhab, riseSetAngle: riseSetAngle
        )

        // Polar day/night: the sun never crosses the horizon, so sunrise and
        // sunset do not exist and every angle-based time is undefined. Fall back
        // to a mid-latitude reference for those times, keeping Dhuhr and Asr
        // (which are always defined) from the real latitude.
        var usedPolarFallback = false
        if raw.hours[.sunrise]?.isNaN ?? true || raw.sunset.isNaN {
            let referenceLatitude = latitude < 0 ? -polarReferenceLatitude : polarReferenceLatitude
            let reference = rawSolarDay(
                jd: jd, latitude: referenceLatitude, method: options.method,
                madhab: options.madhab, riseSetAngle: riseSetAngle
            )
            usedPolarFallback = true
            raw.hours[.fajr] = reference.hours[.fajr]
            raw.hours[.sunrise] = reference.hours[.sunrise]
            raw.hours[.maghrib] = reference.hours[.maghrib]
            raw.hours[.isha] = reference.hours[.isha]
            raw.sunset = reference.sunset
        }

        var hours = raw.hours
        var sunsetHour = raw.sunset

        // Shift onto the requested timezone's wall clock. Everything from here
        // on, including `sunsetHour`, is in display-timezone wall clock hours.
        let shift = offsetHours - longitude / 15.0
        for key in hours.keys { hours[key]! += shift }
        sunsetHour += shift

        // High-latitude correction, applied to angle-derived times only.
        if options.highLatitudeRule != .none,
           let sunriseHour = hours[.sunrise], !sunriseHour.isNaN,
           !sunsetHour.isNaN {
            let night = hourDifference(sunsetHour, sunriseHour)
            func portion(_ angle: Double) -> Double {
                switch options.highLatitudeRule {
                // `.automatic` follows the Aladhan default (angle based) so that
                // switching between fetched and calculated times does not make
                // Fajr and Isha jump by an hour at extreme latitudes.
                case .automatic, .angleBased: return angle / 60.0 * night
                case .oneSeventh: return night / 7.0
                default: return night / 2.0 // .middleOfNight
                }
            }
            func adjust(_ time: Double?, base: Double, angle: Double, counterClockwise: Bool) -> Double {
                guard let time, !time.isNaN else {
                    return base + (counterClockwise ? -portion(angle) : portion(angle))
                }
                let allowed = portion(angle)
                let diff = counterClockwise
                    ? hourDifference(time, base)
                    : hourDifference(base, time)
                return diff > allowed
                    ? base + (counterClockwise ? -allowed : allowed)
                    : time
            }
            hours[.fajr] = adjust(hours[.fajr], base: sunriseHour, angle: options.method.fajrAngle, counterClockwise: true)
            if let maghribAngle = options.method.maghribAngle {
                hours[.maghrib] = adjust(hours[.maghrib], base: sunsetHour, angle: maghribAngle, counterClockwise: false)
            }
            if options.method.ishaInterval == nil {
                hours[.isha] = adjust(hours[.isha], base: sunsetHour, angle: options.method.ishaAngle, counterClockwise: false)
            }
        }

        // Interval-based Maghrib (Portugal, Jordan), applied before Isha because
        // an interval-based Isha is measured from Maghrib.
        if let interval = options.method.maghribInterval, !sunsetHour.isNaN {
            hours[.maghrib] = sunsetHour + interval / 60.0
        }

        // Interval-based Isha, measured from Maghrib (Umm al-Qura, Gulf, Qatar, Lisbon).
        if let interval = options.method.ishaInterval, let maghrib = hours[.maghrib], !maghrib.isNaN {
            hours[.isha] = maghrib + interval / 60.0
        }

        // Tuning: method defaults first, then the user's own offsets.
        for prayer in Prayer.allCases {
            guard var value = hours[prayer], !value.isNaN else { continue }
            value += options.method.adjustment(for: prayer) / 60.0
            value += (options.userAdjustments[prayer.rawValue] ?? 0) / 60.0
            hours[prayer] = value
        }

        // Resolve each wall-clock hour to an absolute instant, allowing the
        // result to roll into an adjacent day (common for Isha in summer).
        func resolve(_ value: Double?) -> Date? {
            guard let value, !value.isNaN else { return nil }
            var hour = value
            var dayOffset = 0
            while hour < 0 { hour += 24; dayOffset -= 1 }
            while hour >= 24 { hour -= 24; dayOffset += 1 }
            let base = calendar.date(byAdding: .day, value: dayOffset, to: dayStart) ?? dayStart
            return base.addingTimeInterval(hour * 3600)
        }

        var resolved: [Prayer: Date] = [:]
        for prayer in Prayer.allCases {
            if let value = resolve(hours[prayer]) { resolved[prayer] = value }
        }

        // Islamic midnight and the last third of the night. Ja'fari/Tehran
        // measure the night from sunset to Fajr; everyone else to sunrise.
        var midnight: Date?
        var lastThird: Date?
        let nightEndPrayer: Prayer = options.method.midnightFromFajr ? .fajr : .sunrise
        if let sunsetValue = resolve(sunsetHour),
           let nightEndHour = hours[nightEndPrayer], !nightEndHour.isNaN {
            let night = hourDifference(sunsetHour, nightEndHour)
            midnight = sunsetValue.addingTimeInterval(night / 2.0 * 3600)
            lastThird = sunsetValue.addingTimeInterval(night * 2.0 / 3.0 * 3600)
        }

        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.timeZone = timeZone

        return PrayerTimes(
            dayStart: dayStart,
            times: resolved,
            midnight: midnight,
            lastThird: lastThird,
            source: .calculated,
            methodName: options.method.name,
            timeZoneIdentifier: timeZone.identifier,
            coordinate: coordinate,
            hijri: HijriDate(from: dayStart, calendar: hijriCalendar, adjustment: 0),
            usedPolarFallback: usedPolarFallback
        )
    }

    // MARK: - Solar geometry

    /// Compute the day's solar hours at a given latitude, in local mean solar
    /// time (no timezone applied yet).
    private static func rawSolarDay(
        jd: Double,
        latitude: Double,
        method: CalculationMethod,
        madhab: Madhab,
        riseSetAngle: Double
    ) -> RawSolarDay {
        func midDay(_ time: Double) -> Double {
            let eqt = sunPosition(julianDate: jd + time / 24.0).equationOfTime
            return Astro.fixHour(12.0 - eqt)
        }

        /// Hour of the day at which the sun sits `angle` degrees below the
        /// horizon. Returns NaN when it never does (polar day/night).
        func sunAngleTime(_ angle: Double, _ time: Double, counterClockwise: Bool) -> Double {
            let declination = sunPosition(julianDate: jd + time / 24.0).declination
            let noon = midDay(time)
            let numerator = -Astro.sinDeg(angle) - Astro.sinDeg(declination) * Astro.sinDeg(latitude)
            let denominator = Astro.cosDeg(declination) * Astro.cosDeg(latitude)
            guard denominator != 0 else { return .nan }
            let ratio = numerator / denominator
            guard ratio <= 1.0, ratio >= -1.0 else { return .nan }
            let hourAngle = Astro.acosDeg(ratio) / 15.0
            return noon + (counterClockwise ? -hourAngle : hourAngle)
        }

        func asrTime(_ shadowFactor: Double, _ time: Double) -> Double {
            // Known limitation: at very high latitudes on short days the sun's
            // maximum altitude can sit barely above the Asr threshold, which
            // makes the result ill-conditioned — a tenth of a degree of solar
            // declination is worth many minutes. Aladhan and this engine can
            // therefore differ by ~20 minutes at places like Svalbard in early
            // winter, while agreeing everywhere the sun actually climbs.
            let declination = sunPosition(julianDate: jd + time / 24.0).declination
            let angle = -Astro.acotDeg(shadowFactor + Astro.tanDeg(abs(latitude - declination)))
            return sunAngleTime(angle, time, counterClockwise: false)
        }

        // Left NaN for Isha when the method defines it as a fixed interval.
        let hours: [Prayer: Double] = [
            .fajr: sunAngleTime(method.fajrAngle, 5, counterClockwise: true),
            .sunrise: sunAngleTime(riseSetAngle, 6, counterClockwise: true),
            .dhuhr: midDay(12),
            .asr: asrTime(madhab.asrShadowFactor, 13),
            .maghrib: sunAngleTime(method.maghribAngle ?? riseSetAngle, 18, counterClockwise: false),
            .isha: method.ishaInterval == nil
                ? sunAngleTime(method.ishaAngle, 18, counterClockwise: false)
                : .nan,
        ]

        return RawSolarDay(hours: hours, sunset: sunAngleTime(riseSetAngle, 18, counterClockwise: false))
    }
}
