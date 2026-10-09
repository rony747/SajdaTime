import Foundation

/// Angle/trig helpers working in degrees, mirroring the conventions used by the
/// widely cross-checked PrayTimes reference implementation so that results can
/// be compared against it and against the Aladhan API.
enum Astro {
    static let degree = Double.pi / 180.0

    /// Reduce to [0, 360).
    static func fixAngle(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Reduce to [0, 24).
    static func fixHour(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 24)
        return r < 0 ? r + 24 : r
    }

    static func sinDeg(_ degrees: Double) -> Double { sin(degrees * degree) }
    static func cosDeg(_ degrees: Double) -> Double { cos(degrees * degree) }
    static func tanDeg(_ degrees: Double) -> Double { tan(degrees * degree) }
    static func asinDeg(_ value: Double) -> Double { asin(value) / degree }
    static func acosDeg(_ value: Double) -> Double { acos(value) / degree }
    static func atan2Deg(_ y: Double, _ x: Double) -> Double { atan2(y, x) / degree }
    /// Inverse cotangent in degrees.
    static func acotDeg(_ value: Double) -> Double { atan(1.0 / value) / degree }
}

/// Apparent position of the sun for a given Julian day.
struct SolarPosition {
    /// Declination in degrees.
    let declination: Double
    /// Equation of time in hours.
    let equationOfTime: Double
}

/// Solar position using the low-precision NOAA/Meeus series, which is accurate
/// to well under a minute of prayer time for our purposes.
func sunPosition(julianDate jd: Double) -> SolarPosition {
    let d = jd - 2451545.0
    let g = Astro.fixAngle(357.529 + 0.98560028 * d)
    let q = Astro.fixAngle(280.459 + 0.98564736 * d)
    let l = Astro.fixAngle(q + 1.915 * Astro.sinDeg(g) + 0.020 * Astro.sinDeg(2 * g))
    let e = 23.439 - 0.00000036 * d
    let ra = Astro.atan2Deg(Astro.cosDeg(e) * Astro.sinDeg(l), Astro.cosDeg(l)) / 15.0
    let declination = Astro.asinDeg(Astro.sinDeg(e) * Astro.sinDeg(l))
    // Deliberately left un-normalised; every consumer wraps the final wall-clock
    // hour back into [0, 24), which cancels the 24-hour ambiguity here.
    let equationOfTime = q / 15.0 - Astro.fixHour(ra)
    return SolarPosition(declination: declination, equationOfTime: equationOfTime)
}

/// Julian day number for a Gregorian calendar date (at 00:00 UT).
func julianDay(year: Int, month: Int, day: Int) -> Double {
    var y = year
    var m = month
    if m <= 2 {
        y -= 1
        m += 12
    }
    let a = floor(Double(y) / 100.0)
    let b = 2.0 - a + floor(a / 4.0)
    return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
}

/// Signed difference between two clock hours, wrapped into [0, 24).
func hourDifference(_ a: Double, _ b: Double) -> Double {
    Astro.fixHour(b - a)
}
