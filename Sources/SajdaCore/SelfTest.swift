import Foundation

/// A single failed invariant.
public struct SelfTestFailure: Sendable {
    public let name: String
    public let detail: String

    public init(name: String, detail: String) {
        self.name = name
        self.detail = detail
    }
}

/// Executable specification for the calculation engine.
///
/// This lives in the library rather than in the test target so that the same
/// checks can be run two ways: through `XCTest` in Xcode, and through
/// `sajdactl selftest` on a machine where only a command line toolchain is
/// available. One copy of the assertions, two runners.
public enum SajdaCoreSelfTest {

    public static func run() -> [SelfTestFailure] {
        var failures: [SelfTestFailure] = []

        func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
            if !condition {
                failures.append(SelfTestFailure(name: name, detail: detail()))
            }
        }

        func times(
            lat: Double, lng: Double, tz: String, method: String = "MWL",
            madhab: Madhab = .standard,
            highLatitude: HighLatitudeRule = .automatic,
            date: String
        ) -> PrayerTimes {
            let zone = TimeZone(identifier: tz)!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = zone
            let day = formatter.date(from: date)!
            return PrayerCalculator.calculate(
                date: day,
                coordinate: Coordinate(latitude: lat, longitude: lng),
                timeZone: zone,
                options: .init(method: CalculationMethod.method(id: method), madhab: madhab, highLatitudeRule: highLatitude)
            )
        }

        func hour(_ date: Date, _ tz: String) -> Double {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: tz)!
            let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
            return Double(parts.hour!) + Double(parts.minute!) / 60 + Double(parts.second!) / 3600
        }

        let allInOrder = [Prayer.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

        // 1. Mid-latitude summer day unfolds in the expected order.
        let istanbul = times(lat: 41.0082, lng: 28.9784, tz: "Europe/Istanbul", method: "TURKEY", madhab: .hanafi, date: "2026-06-15")
        check("istanbul.ordering", istanbul.ordered.map(\.prayer) == allInOrder,
              "got \(istanbul.ordered.map(\.prayer))")

        // 2. Dhuhr sits at solar noon, ~13:05 local for Istanbul in mid June.
        let dhuhr = hour(istanbul.times[.dhuhr]!, "Europe/Istanbul")
        check("istanbul.dhuhr", abs(dhuhr - 13.08) < 0.2, String(format: "got %.3f", dhuhr))

        // 3. Polar summer: the sun barely sets, so the engine substitutes a
        //    mid-latitude reference. The day must still be complete and ordered,
        //    and the substitution must be flagged rather than hidden.
        let tromso = times(lat: 69.6492, lng: 18.9553, tz: "Europe/Oslo", date: "2026-06-21")
        check("tromso.ordering", tromso.ordered.map(\.prayer) == allInOrder,
              "got \(tromso.ordered.map(\.prayer))")
        check("tromso.polarFlag", tromso.usedPolarFallback, "polar fallback not flagged")

        // 4. Hanafi Asr is always later than standard Asr.
        let standardAsr = times(lat: 24.8607, lng: 67.0011, tz: "Asia/Karachi", method: "KARACHI", madhab: .standard, date: "2026-03-10")
        let hanafiAsr = times(lat: 24.8607, lng: 67.0011, tz: "Asia/Karachi", method: "KARACHI", madhab: .hanafi, date: "2026-03-10")
        check("asr.hanafiLater", hanafiAsr.times[.asr]! > standardAsr.times[.asr]!,
              "hanafi \(hanafiAsr.times[.asr]!) standard \(standardAsr.times[.asr]!)")

        // 5. Umm al-Qura defines Isha as exactly 90 minutes after Maghrib.
        let makkah = times(lat: 21.4225, lng: 39.8262, tz: "Asia/Riyadh", method: "MAKKAH", date: "2026-06-15")
        let ishaGap = makkah.times[.isha]!.timeIntervalSince(makkah.times[.maghrib]!)
        check("makkah.isha90", abs(ishaGap - 90 * 60) < 60, "gap \(ishaGap / 60) min")

        // 6. Angle-based Isha follows Maghrib within a sane window.
        let karachi = times(lat: 24.8607, lng: 67.0011, tz: "Asia/Karachi", method: "KARACHI", date: "2026-06-15")
        check("karachi.ishaAfterMaghrib",
              karachi.times[.isha]! > karachi.times[.maghrib]! &&
              karachi.times[.isha]! < karachi.times[.maghrib]!.addingTimeInterval(3 * 3600))

        // 7. Southern hemisphere, summer solstice.
        let sydney = times(lat: -33.8688, lng: 151.2093, tz: "Australia/Sydney", date: "2026-12-21")
        check("sydney.ordering", sydney.ordered.map(\.prayer) == allInOrder,
              "got \(sydney.ordered.map(\.prayer))")

        // 8. Polar night must not produce NaN or crash.
        let svalbard = times(lat: 78.2232, lng: 15.6469, tz: "Arctic/Longyearbyen", date: "2026-12-21")
        for (_, value) in svalbard.ordered {
            check("svalbard.finite", !value.timeIntervalSince1970.isNaN, "NaN time")
        }

        // 9. Solar position against published values for 2026-06-15.
        let position = sunPosition(julianDate: julianDay(year: 2026, month: 6, day: 15))
        check("solar.declination", abs(position.declination - 23.3) < 0.5, String(format: "%.3f", position.declination))
        check("solar.equationOfTime", abs(position.equationOfTime * 60 + 0.3) < 1.5,
              String(format: "%.3f min", position.equationOfTime * 60))

        // 10. Aladhan clock strings carry a timezone suffix that must be stripped.
        check("aladhan.parseSuffix",
              AladhanClient.parseClock("05:38 (EEST)")?.hour == 5 &&
              AladhanClient.parseClock("05:38 (EEST)")?.minute == 38)
        check("aladhan.parsePlain", AladhanClient.parseClock("21:07")?.hour == 21)
        check("aladhan.parseRejects", AladhanClient.parseClock("n/a") == nil)

        // 11. Hijri rendering matches the reference app's wording.
        check("hijri.formatted", HijriDate(day: 28, monthIndex: 4, year: 1448).formatted == "28 Rabi' II 1448 AH")
        check("hijri.numeric", HijriDate(day: 28, monthIndex: 4, year: 1448).numeric == "28-04-1448")

        // 12. Country to method auto-detection.
        check("method.auto.pk", CalculationMethod.autoDetected(forCountryCode: "PK").id == "KARACHI")
        check("method.auto.sa", CalculationMethod.autoDetected(forCountryCode: "sa").id == "MAKKAH")
        check("method.auto.us", CalculationMethod.autoDetected(forCountryCode: "US").id == "ISNA")
        check("method.auto.fallback", CalculationMethod.autoDetected(forCountryCode: "ZZ").id == "MWL")

        // 13. A timezone far from the location must still yield a coherent day.
        let shifted = times(lat: 41.0082, lng: 28.9784, tz: "America/New_York", method: "TURKEY", date: "2026-06-15")
        check("timezone.shift", shifted.ordered.count == 6, "missing times when timezone is remote")

        // 14. Prayer windows. A prayer's remaining time is its own valid window,
        //     not the gap until the next prayer: Fajr ends at sunrise.
        let dhaka = times(lat: 23.8103, lng: 90.4125, tz: "Asia/Dhaka", method: "KARACHI", madhab: .hanafi, date: "2026-06-15")
        let dhakaNext = times(lat: 23.8103, lng: 90.4125, tz: "Asia/Dhaka", method: "KARACHI", madhab: .hanafi, date: "2026-06-16")

        let fajrWindow = dhaka.window(for: .fajr)
        check("window.fajrExists", fajrWindow != nil, "no Fajr window")
        if let fajrWindow {
            check("window.fajrEndsAtSunrise", fajrWindow.end == dhaka.times[.sunrise],
                  "Fajr window does not end at sunrise")

            // The regression this guards: Fajr's window must not stretch to Dhuhr.
            let untilDhuhr = dhaka.times[.dhuhr]!.timeIntervalSince(fajrWindow.start)
            check("window.fajrIsShort",
                  fajrWindow.duration < 2 * 3600 && fajrWindow.duration < untilDhuhr / 2,
                  String(format: "Fajr window %.0f min vs %.0f min until Dhuhr",
                         fajrWindow.duration / 60, untilDhuhr / 60))

            // Inside the window it is the current prayer; after sunrise it is not.
            check("window.activeDuringFajr",
                  dhaka.activeWindow(at: fajrWindow.start.addingTimeInterval(60))?.prayer == .fajr)
            check("window.gapAfterSunrise",
                  dhaka.activeWindow(at: fajrWindow.end.addingTimeInterval(60)) == nil,
                  "a prayer window was reported between sunrise and Dhuhr")
        }

        // Windows run in order and never overlap.
        let windows = dhaka.windows(nextDay: dhakaNext)
        check("window.ordering", windows.map(\.prayer) == [.fajr, .dhuhr, .asr, .maghrib, .isha],
              "got \(windows.map(\.prayer))")
        check("window.nonOverlapping",
              zip(windows, windows.dropFirst()).allSatisfy { $0.end <= $1.start },
              "windows overlap")

        // Dhuhr, Asr and Maghrib each run until the next prayer begins.
        check("window.dhuhrEndsAtAsr", dhaka.window(for: .dhuhr)?.end == dhaka.times[.asr])
        check("window.asrEndsAtMaghrib", dhaka.window(for: .asr)?.end == dhaka.times[.maghrib])
        check("window.maghribEndsAtIsha", dhaka.window(for: .maghrib)?.end == dhaka.times[.isha])

        // Isha's chosen time ends at Islamic midnight, not at Fajr.
        let ishaWindow = dhaka.window(for: .isha, nextDay: dhakaNext)
        check("window.ishaEndsAtMidnight", ishaWindow?.end == dhaka.midnight,
              "Isha's window does not end at Islamic midnight")
        check("window.ishaNecessityEndsAtFajr", ishaWindow?.necessityEnd == dhakaNext.times[.fajr])

        // The overnight part of Isha's window is only found when yesterday is
        // supplied, which is why the app loads three days.
        if let midnight = dhaka.midnight {
            let justBeforeMidnight = midnight.addingTimeInterval(-600)
            check("window.ishaSpansMidnight",
                  dhakaNext.activeWindow(at: justBeforeMidnight, previousDay: dhaka)?.prayer == .isha,
                  "Isha's window was not detected after midnight")
            check("window.needsPreviousDay",
                  dhakaNext.activeWindow(at: justBeforeMidnight) == nil,
                  "a window was reported without the previous day's Isha")
        }

        // 15. Cached days must survive a JSON round trip exactly, and must be
        //     stored with named keys rather than an order-dependent array.
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(istanbul)
            let json = String(data: data, encoding: .utf8) ?? ""
            check("cache.namedKeys", json.contains("\"fajr\"") && json.contains("\"maghrib\""),
                  "times were not stored with prayer-name keys")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let restored = try decoder.decode(PrayerTimes.self, from: data)

            // ISO-8601 has one-second resolution, so instants are compared with
            // a one-second tolerance; everything else must match exactly.
            let timesMatch = Prayer.allCases.allSatisfy { prayer in
                guard let before = istanbul.times[prayer], let after = restored.times[prayer] else { return false }
                return abs(after.timeIntervalSince(before)) <= 1.0
            }
            check(
                "cache.roundTrip",
                timesMatch
                    && restored.methodName == istanbul.methodName
                    && restored.coordinate == istanbul.coordinate
                    && restored.source == istanbul.source
                    && restored.hijri == istanbul.hijri
                    && restored.timeZoneIdentifier == istanbul.timeZoneIdentifier
                    && restored.usedPolarFallback == istanbul.usedPolarFallback,
                "decoded value differs from the original"
            )
        } catch {
            check("cache.roundTrip", false, "\(error)")
        }

        // 16. Menu bar label composition. A countdown that silently fails to
        //     render is invisible until someone looks at the menu bar, so the
        //     composition is asserted here.
        let full = MenuBarComposer.content(
            style: .iconNameCountdown, prayerName: "Fajr",
            prayerSymbol: "sunrise.fill", countdown: "53m"
        )
        check("menubar.showsIcon", full.symbolName == "sunrise.fill")
        check("menubar.showsName", full.text.contains("Fajr"), "got \(full.text)")
        check("menubar.showsCountdown", full.text.contains("53m"), "got \(full.text)")
        check("menubar.fullText", full.text == "Fajr 53m", "got \(full.text)")

        let iconOnly = MenuBarComposer.content(
            style: .iconOnly, prayerName: "Fajr",
            prayerSymbol: "sunrise.fill", countdown: "53m"
        )
        check("menubar.iconOnly", iconOnly.symbolName == "sunrise.fill" && iconOnly.text.isEmpty,
              "got symbol=\(String(describing: iconOnly.symbolName)) text=\(iconOnly.text)")

        // The default style must always include the remaining time.
        let defaulted = MenuBarComposer.content(
            style: MenuBarLabelStyle(rawValue: "iconNameCountdown") ?? .iconNameCountdown,
            prayerName: "Isha", prayerSymbol: "moon.stars.fill", countdown: "2h 10m"
        )
        check("menubar.defaultIncludesCountdown", defaulted.text.contains("2h 10m"), "got \(defaulted.text)")

        // 17. First-launch location must come from the system timezone, never a
        //     hard-coded foreign city.
        guard let dhakaZone = TimeZone(identifier: "Asia/Dhaka") else {
            check("location.dhakaZone", false, "Asia/Dhaka unavailable")
            return failures
        }
        let seeded = AppSettings.fresh(for: dhakaZone)
        check("location.seededFromTimeZone",
              abs(seeded.latitude - 23.8103) < 0.5 && abs(seeded.longitude - 90.4125) < 0.5,
              "got \(seeded.latitude), \(seeded.longitude)")
        check("location.notIstanbul", seeded.locationName != "Istanbul", "got \(seeded.locationName)")
        check("location.methodAutoDetected", seeded.methodID == "KARACHI", "got \(seeded.methodID)")
        check("location.flaggedEstimated", seeded.locationIsEstimated)
        check("location.usable", seeded.hasUsableLocation)
        check("location.zoneMatches", seeded.displayTimeZone.identifier == "Asia/Dhaka")

        // A zone we do not list still resolves within its region.
        if let oddZone = TimeZone(identifier: "Asia/Choibalsan") {
            let odd = AppSettings.fresh(for: oddZone)
            check("location.regionalFallback", odd.hasUsableLocation,
                  "unlisted zone produced no usable position")
        }

        // 18. Clock format preference must actually change the output.
        let zone = TimeZone(identifier: "Asia/Dhaka")!
        var components = DateComponents()
        components.year = 2026; components.month = 1; components.day = 22
        components.hour = 17; components.minute = 24
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let sample = calendar.date(from: components)!

        let twelve = TimeFormatting.clock(sample, timeZone: zone, format: .twelveHour)
        let twentyFour = TimeFormatting.clock(sample, timeZone: zone, format: .twentyFourHour)
        check("clock.12h", twelve == "5:24 PM", "got \(twelve)")
        check("clock.24h", twentyFour == "17:24", "got \(twentyFour)")

        // Countdowns are written the same way regardless of the clock preference.
        check("clock.countdown", TimeFormatting.countdown(5060) == "01:24:20", "got \(TimeFormatting.countdown(5060))")
        check("clock.compact", TimeFormatting.countdown(5060, style: .compact) == "1h 24m",
              "got \(TimeFormatting.countdown(5060, style: .compact))")

        // The settings helper must follow the stored preference.
        var settings = AppSettings.fresh(for: zone)
        settings.clockFormat = .twentyFourHour
        check("clock.setting24", settings.clock(sample) == "17:24", "got \(settings.clock(sample))")
        settings.clockFormat = .twelveHour
        check("clock.setting12", settings.clock(sample) == "5:24 PM", "got \(settings.clock(sample))")

        // 19. Qibla bearings, against published directions.
        let qiblaCases: [(String, Coordinate, Double, Double)] = [
            ("dhaka", Coordinate(latitude: 23.8103, longitude: 90.4125), 277.57, 5172),
            ("london", Coordinate(latitude: 51.5072, longitude: -0.1276), 118.99, 4794),
            ("newyork", Coordinate(latitude: 40.7128, longitude: -74.0060), 58.48, 10306),
            ("cairo", Coordinate(latitude: 30.0444, longitude: 31.2357), 136.14, 1287),
        ]
        for (label, coordinate, expectedBearing, expectedDistance) in qiblaCases {
            let bearing = Qibla.bearing(from: coordinate)
            let distance = Qibla.distance(from: coordinate)
            check("qibla.\(label).bearing", abs(bearing - expectedBearing) < 0.5,
                  String(format: "got %.2f expected %.2f", bearing, expectedBearing))
            check("qibla.\(label).distance", abs(distance - expectedDistance) < 5,
                  String(format: "got %.1f expected %.1f", distance, expectedDistance))
        }
        check("qibla.atKaaba", Qibla.distance(from: Qibla.kaaba) < 0.001)
        check("qibla.compassPoint", Qibla.compassPoint(for: 277.57) == "W",
              "got \(Qibla.compassPoint(for: 277.57))")

        // 20. A window's start and end are shown together, with the meridiem
        //     written once when both ends share it.
        func at(_ hour: Int, _ minute: Int) -> Date {
            var c = DateComponents()
            c.year = 2026; c.month = 1; c.day = 22; c.hour = hour; c.minute = minute
            return calendar.date(from: c)!
        }
        check("clock.range12Morning",
              TimeFormatting.clockRange(at(5, 24), at(6, 43), timeZone: zone, format: .twelveHour) == "5:24 – 6:43 AM",
              "got \(TimeFormatting.clockRange(at(5, 24), at(6, 43), timeZone: zone, format: .twelveHour))")
        check("clock.range12Crossing",
              TimeFormatting.clockRange(at(11, 30), at(13, 15), timeZone: zone, format: .twelveHour) == "11:30 AM – 1:15 PM",
              "got \(TimeFormatting.clockRange(at(11, 30), at(13, 15), timeZone: zone, format: .twelveHour))")
        check("clock.range24",
              TimeFormatting.clockRange(at(5, 24), at(6, 43), timeZone: zone, format: .twentyFourHour) == "05:24 – 06:43",
              "got \(TimeFormatting.clockRange(at(5, 24), at(6, 43), timeZone: zone, format: .twentyFourHour))")

        return failures
    }
}
