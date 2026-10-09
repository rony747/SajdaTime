import Foundation
import SajdaCore

/// Verification harness. Not shipped to users: it exists so the offline
/// calculator can be checked against the live Aladhan service and so the
/// engine's invariants can be run without an XCTest bundle.
@main
struct SajdaTimeCtl {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(2)
        }

        switch command {
        case "show":
            await show(Array(args.dropFirst()))
        case "compare":
            await compare()
        case "methods":
            await methods()
        case "matrix":
            await matrix()
        case "selftest":
            selftest()
        case "store":
            await storeProbe()
        case "seed-appearance":
            seedAppearance(Array(args.dropFirst()))
        case "countdown":
            await countdown(Array(args.dropFirst()))
        default:
            printUsage()
            exit(2)
        }
    }

    static func printUsage() {
        print("""
        sajdactl — prayer time verification

          show <lat> <lng> <tz> [--method ID] [--school 0|1] [--date YYYY-MM-DD]
              Print calculated and fetched times for one location.

          compare
              Check a fixed set of cities against the live API.

          methods
              Check every calculation method this app ships.

          matrix
              Sweep latitudes (including polar cases) against the live API.

          selftest
              Run the engine's invariant checks (same set as the XCTest target).

          store
              Exercise the exact load path the app uses, including the cache.

          seed-appearance <system|light|dark>
              Write a settings blob with that appearance into the app's own
              preferences domain. A development aid: the app's UI cannot
              otherwise be exercised without a screen.

          countdown <lat> <lng> <tz> [--method ID] [--school 0|1] [--date YYYY-MM-DD]
              Simulate the menu bar across a whole day, showing each prayer's
              remaining window rather than the gap to the next prayer.

        Set PRAYERCTL_SECONDS=1 for second-level output.
        """)
    }

    /// Write a settings blob into the app's preferences domain so a specific
    /// appearance can be exercised. Development aid only.
    static func seedAppearance(_ args: [String]) {
        guard let raw = args.first, let appearance = AppAppearance(rawValue: raw) else {
            print("usage: sajdactl seed-appearance <system|light|dark>")
            exit(2)
        }
        var settings = AppSettings.fresh(for: .current)
        settings.appearance = appearance
        guard let data = try? JSONEncoder().encode(settings) else {
            print("could not encode settings"); exit(1)
        }
        let domain = "app.local.sajdatime"
        guard let defaults = UserDefaults(suiteName: domain) else {
            print("could not open domain \(domain)"); exit(1)
        }
        defaults.set(data, forKey: "\(domain).settings.v2")
        // Skip the app's first-run location seeding so the value is not reset.
        defaults.set(true, forKey: "\(domain).migrated.windowCountdown")
        defaults.synchronize()
        print("seeded \(domain) with appearance=\(appearance.rawValue) (\(data.count) bytes)")
    }

    /// Mirrors `AppState.refresh()` so the app's data path can be verified
    /// without a GUI: same settings, same store, same cache.
    static func storeProbe() async {
        // Mirrors a first launch: location seeded from the system timezone.
        let settings = AppSettings.fresh(for: .current)
        let zone = settings.displayTimeZone
        let cache = PrayerTimesCache()
        let store = PrayerTimesStore(cache: cache)

        print("cache directory: \(cache.location.path)")
        print("timezone       : \(zone.identifier)")
        print("method         : \(settings.methodID) (\(settings.method.name))")
        print("location       : \(settings.locationName) (\(settings.countryCode)) \(settings.latitude), \(settings.longitude)")
        print("fetch live     : \(settings.fetchLiveTimes)")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let dayStart = calendar.startOfDay(for: Date())

        let times = await store.times(for: settings, date: dayStart)
        print("\nsource         : \(times.source.label)")
        print("entries        : \(times.times.count)")
        for (prayer, value) in times.ordered {
            print("  \(prayer.displayName.padded(to: 9)) \(clockFormatter(zone).string(from: value))")
        }

        // A second call must be served from the cache we just wrote.
        let again = await store.times(for: settings, date: dayStart)
        print("\nsecond call    : \(again.source.label)")
        if let error = cache.lastError {
            print("cache error    : \(error)")
        } else {
            let files = (try? FileManager.default.contentsOfDirectory(at: cache.location, includingPropertiesForKeys: nil)) ?? []
            print("cache files    : \(files.filter { $0.pathExtension == "json" }.count)")
        }
    }

    static func selftest() {
        let failures = SajdaCoreSelfTest.run()
        if failures.isEmpty {
            print("selftest: all engine invariants hold.")
            return
        }
        print("selftest: \(failures.count) failure(s)")
        for failure in failures {
            print("  ✗ \(failure.name)\(failure.detail.isEmpty ? "" : " — \(failure.detail)")")
        }
        exit(1)
    }

    // MARK: - show

    /// Parsed location arguments shared by `show` and `countdown`.
    struct LocationQuery {
        var coordinate: Coordinate
        var zone: TimeZone
        var method: CalculationMethod
        var madhab: Madhab
        var date: Date

        var formatter: DateFormatter { SajdaTimeCtl.clockFormatter(zone) }

        /// Times for the query's day, plus the day before and after, which the
        /// window logic needs across midnight.
        func days() -> (previous: PrayerTimes, today: PrayerTimes, next: PrayerTimes) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let start = calendar.startOfDay(for: date)
            func day(_ offset: Int) -> PrayerTimes {
                let target = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                return PrayerCalculator.calculate(
                    date: target, coordinate: coordinate, timeZone: zone,
                    options: .init(method: method, madhab: madhab, highLatitudeRule: .automatic)
                )
            }
            return (day(-1), day(0), day(1))
        }
    }

    static func parseLocationQuery(_ args: [String], usage: String) -> LocationQuery {
        guard args.count >= 3,
              let lat = Double(args[0]), let lng = Double(args[1]),
              let zone = TimeZone(identifier: args[2]) else {
            print(usage)
            exit(2)
        }

        var methodId = "MWL"
        var madhab = Madhab.standard
        var date = Date()

        var index = 3
        while index < args.count {
            switch args[index] {
            case "--method":
                if index + 1 < args.count { methodId = args[index + 1]; index += 1 }
            case "--school":
                if index + 1 < args.count, args[index + 1] == "1" { madhab = .hanafi }
                index += 1
            case "--date":
                if index + 1 < args.count {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.timeZone = zone
                    if let parsed = formatter.date(from: args[index + 1]) { date = parsed }
                }
                index += 1
            default:
                break
            }
            index += 1
        }

        return LocationQuery(
            coordinate: Coordinate(latitude: lat, longitude: lng),
            zone: zone,
            method: CalculationMethod.method(id: methodId),
            madhab: madhab,
            date: date
        )
    }

    /// Walk a full day and print what the menu bar would show, proving that the
    /// countdown follows each prayer's own window.
    static func countdown(_ args: [String]) async {
        let query = parseLocationQuery(
            args,
            usage: "usage: sajdactl countdown <lat> <lng> <tz> [--method ID] [--school 0|1] [--date YYYY-MM-DD]"
        )
        let (previous, today, next) = query.days()
        let formatter = query.formatter

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = query.zone
        let start = calendar.startOfDay(for: query.date)

        print("Menu bar simulation — \(query.method.name), \(query.madhab.rawValue), \(query.zone.identifier)\n")
        print("time   window     remaining   ends at      (or next prayer)")

        for minute in stride(from: 0, to: 24 * 60, by: 30) {
            guard let moment = calendar.date(byAdding: .minute, value: minute, to: start) else { continue }
            let clock = formatter.string(from: moment)

            if let window = today.activeWindow(at: moment, previousDay: previous, nextDay: next) {
                let remaining = Int((window.remaining(at: moment) / 60).rounded())
                print("\(clock)  \(window.prayer.displayName.padded(to: 9))  "
                    + "\(String(format: "%4d", remaining)) min   "
                    + "\(formatter.string(from: window.end))  (\(window.endLabel))")
            } else if let upcoming = today.nextPrayer(after: moment) {
                let remaining = Int((upcoming.date.timeIntervalSince(moment) / 60).rounded())
                print("\(clock)  \("—".padded(to: 9))  "
                    + "\(String(format: "%4d", remaining)) min   "
                    + "\(formatter.string(from: upcoming.date))  (next: \(upcoming.prayer.displayName))")
            } else {
                print("\(clock)  —")
            }
        }
    }

    static func show(_ args: [String]) async {
        let query = parseLocationQuery(
            args,
            usage: "usage: sajdactl show <lat> <lng> <tz> [--method ID] [--school 0|1] [--date YYYY-MM-DD]"
        )
        let coordinate = query.coordinate
        let zone = query.zone
        let method = query.method
        let madhab = query.madhab
        let date = query.date
        let formatter = query.formatter

        let local = PrayerCalculator.calculate(
            date: date, coordinate: coordinate, timeZone: zone,
            options: .init(method: method, madhab: madhab, highLatitudeRule: .automatic)
        )

        print("Calculated  (\(method.name), \(madhab.rawValue))")
        for (prayer, value) in local.ordered {
            print("  \(prayer.displayName.padded(to: 9)) \(formatter.string(from: value))")
        }
        print("  Hijri: \(local.hijri?.formatted ?? "n/a")")
        if local.usedPolarFallback {
            print("  note: no sunrise/sunset at this latitude; mid-latitude reference used")
        }

        // Prayer windows: how long each prayer actually remains valid. Fajr is
        // measured to sunrise, Isha to Islamic midnight.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let nextDayDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let nextDay = PrayerCalculator.calculate(
            date: nextDayDate, coordinate: coordinate, timeZone: zone,
            options: .init(method: method, madhab: madhab, highLatitudeRule: .automatic)
        )

        print("\nWindows")
        print("  prayer     starts   ends     duration  ends at")
        for window in local.windows(nextDay: nextDay) {
            let duration = Int((window.duration / 60).rounded())
            print("  \(window.prayer.displayName.padded(to: 9)) "
                + "\(formatter.string(from: window.start))  "
                + "\(formatter.string(from: window.end))  "
                + "\(String(format: "%4d", duration)) min  "
                + "\(window.endLabel)")
            if let necessity = window.necessityEnd {
                print("            (time of necessity until \(formatter.string(from: necessity)))")
            }
        }

        let client = AladhanClient()
        do {
            let fetched = try await client.fetchTimes(
                date: date, coordinate: coordinate, timeZone: zone,
                method: method, madhab: madhab, highLatitudeRule: .automatic
            )
            print("\nAladhan     (\(fetched.methodName))")
            for (prayer, value) in fetched.ordered {
                let delta = local.times[prayer].map { Int(($0.timeIntervalSince(value) / 60).rounded()) }
                let deltaText = delta.map { $0 == 0 ? "  0m" : String(format: "%+4dm", $0) } ?? "  n/a"
                print("  \(prayer.displayName.padded(to: 9)) \(formatter.string(from: value))   Δ \(deltaText)")
            }
        } catch {
            print("\nAladhan fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Comparison sweeps

    struct Sample {
        let label: String
        let lat: Double
        let lng: Double
        let tz: String
        let method: String
        var hanafi: Bool = false
    }

    static let cities: [Sample] = [
        Sample(label: "Istanbul",   lat: 41.0082,  lng: 28.9784,   tz: "Europe/Istanbul",     method: "TURKEY",   hanafi: true),
        Sample(label: "Makkah",     lat: 21.4225,  lng: 39.8262,   tz: "Asia/Riyadh",         method: "MAKKAH"),
        Sample(label: "Karachi",    lat: 24.8607,  lng: 67.0011,   tz: "Asia/Karachi",        method: "KARACHI",  hanafi: true),
        Sample(label: "Cairo",      lat: 30.0444,  lng: 31.2357,   tz: "Africa/Cairo",        method: "EGYPT"),
        Sample(label: "New York",   lat: 40.7128,  lng: -74.0060,  tz: "America/New_York",    method: "ISNA"),
        Sample(label: "London",     lat: 51.5072,  lng: -0.1276,   tz: "Europe/London",       method: "MWL"),
        Sample(label: "Jakarta",    lat: -6.2088,  lng: 106.8456,  tz: "Asia/Jakarta",        method: "KEMENAG"),
        Sample(label: "Dhaka",      lat: 23.8103,  lng: 90.4125,   tz: "Asia/Dhaka",          method: "KARACHI",  hanafi: true),
        Sample(label: "Sydney",     lat: -33.8688, lng: 151.2093,  tz: "Australia/Sydney",    method: "MWL"),
        Sample(label: "LosAngeles", lat: 34.0522,  lng: -118.2437, tz: "America/Los_Angeles", method: "ISNA"),
    ]

    /// One representative location per shipped method, so a method that carries
    /// hidden tuning (as Diyanet does) cannot slip through unnoticed.
    static let methodSamples: [Sample] = [
        Sample(label: "MWL @London",        lat: 51.5072,  lng: -0.1276,  tz: "Europe/London",     method: "MWL"),
        Sample(label: "ISNA @Chicago",      lat: 41.8781,  lng: -87.6298, tz: "America/Chicago",   method: "ISNA"),
        Sample(label: "EGYPT @Cairo",       lat: 30.0444,  lng: 31.2357,  tz: "Africa/Cairo",      method: "EGYPT"),
        Sample(label: "MAKKAH @Jeddah",     lat: 21.4858,  lng: 39.1925,  tz: "Asia/Riyadh",       method: "MAKKAH"),
        Sample(label: "KARACHI @Karachi",   lat: 24.8607,  lng: 67.0011,  tz: "Asia/Karachi",      method: "KARACHI", hanafi: true),
        Sample(label: "TEHRAN @Tehran",     lat: 35.6892,  lng: 51.3890,  tz: "Asia/Tehran",       method: "TEHRAN"),
        Sample(label: "JAFARI @Qom",        lat: 34.6416,  lng: 50.8746,  tz: "Asia/Tehran",       method: "JAFARI"),
        Sample(label: "GULF @Riyadh",       lat: 24.7136,  lng: 46.6753,  tz: "Asia/Riyadh",       method: "GULF"),
        Sample(label: "KUWAIT @KuwaitCity", lat: 29.3759,  lng: 47.9774,  tz: "Asia/Kuwait",       method: "KUWAIT"),
        Sample(label: "QATAR @Doha",        lat: 25.2854,  lng: 51.5310,  tz: "Asia/Qatar",        method: "QATAR"),
        Sample(label: "SINGAPORE @SG",      lat: 1.3521,   lng: 103.8198, tz: "Asia/Singapore",    method: "SINGAPORE"),
        Sample(label: "FRANCE @Paris",      lat: 48.8566,  lng: 2.3522,   tz: "Europe/Paris",      method: "FRANCE"),
        Sample(label: "TURKEY @Istanbul",   lat: 41.0082,  lng: 28.9784,  tz: "Europe/Istanbul",   method: "TURKEY", hanafi: true),
        Sample(label: "RUSSIA @Moscow",     lat: 55.7558,  lng: 37.6173,  tz: "Europe/Moscow",     method: "RUSSIA"),
        Sample(label: "DUBAI @Dubai",       lat: 25.2048,  lng: 55.2708,  tz: "Asia/Dubai",        method: "DUBAI"),
        Sample(label: "JAKIM @KL",          lat: 3.1390,   lng: 101.6869, tz: "Asia/Kuala_Lumpur", method: "JAKIM"),
        Sample(label: "TUNISIA @Tunis",     lat: 36.8065,  lng: 10.1815,  tz: "Africa/Tunis",      method: "TUNISIA"),
        Sample(label: "ALGERIA @Algiers",   lat: 36.7538,  lng: 3.0588,   tz: "Africa/Algiers",    method: "ALGERIA"),
        Sample(label: "KEMENAG @Jakarta",   lat: -6.2088,  lng: 106.8456, tz: "Asia/Jakarta",      method: "KEMENAG"),
        Sample(label: "MOROCCO @Casablanca", lat: 33.5731, lng: -7.5898,  tz: "Africa/Casablanca", method: "MOROCCO"),
        Sample(label: "PORTUGAL @Lisbon",   lat: 38.7223,  lng: -9.1393,  tz: "Europe/Lisbon",     method: "PORTUGAL"),
        Sample(label: "JORDAN @Amman",      lat: 31.9454,  lng: 35.9284,  tz: "Asia/Amman",        method: "JORDAN"),
    ]

    static func compare() async {
        await sweep(title: "Cities", samples: cities, showEveryPrayer: true)
    }

    static func methods() async {
        await sweep(title: "Calculation methods", samples: methodSamples, showEveryPrayer: true)
    }

    static func matrix() async {
        // Deliberately includes polar cases and a southern-hemisphere DST zone,
        // where naive implementations break.
        let polar: [Sample] = [
            Sample(label: "Tromso",    lat: 69.6492,  lng: 18.9553,   tz: "Europe/Oslo",          method: "MWL"),
            Sample(label: "Reykjavik", lat: 64.1466,  lng: -21.9426,  tz: "Atlantic/Reykjavik",   method: "MWL"),
            Sample(label: "Quito",     lat: -0.1807,  lng: -78.4678,  tz: "America/Guayaquil",    method: "MWL"),
            Sample(label: "Perth",     lat: -31.9523, lng: 115.8613,  tz: "Australia/Perth",      method: "MWL"),
            Sample(label: "Anchorage", lat: 61.2181,  lng: -149.9003, tz: "America/Anchorage",    method: "MWL"),
            Sample(label: "Svalbard",  lat: 78.2232,  lng: 15.6469,   tz: "Arctic/Longyearbyen",  method: "MWL"),
        ]
        await sweep(title: "Latitude sweep", samples: polar, showEveryPrayer: true)
    }

    static func sweep(title: String, samples: [Sample], showEveryPrayer: Bool) async {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.timeZone = TimeZone(identifier: "UTC")

        print("\(title) — calculated vs live Aladhan, \(stamp.string(from: Date()))\n")

        var allDeltas: [Int] = []
        var failures: [String] = []
        var polarNotes: [String] = []

        for sample in samples {
            let coordinate = Coordinate(latitude: sample.lat, longitude: sample.lng)
            guard let zone = TimeZone(identifier: sample.tz) else {
                failures.append("\(sample.label): unknown timezone \(sample.tz)")
                continue
            }
            let method = CalculationMethod.method(id: sample.method)
            let madhab: Madhab = sample.hanafi ? .hanafi : .standard
            let clock = clockFormatter(zone)

            let local = PrayerCalculator.calculate(
                date: Date(), coordinate: coordinate, timeZone: zone,
                options: .init(method: method, madhab: madhab, highLatitudeRule: .automatic)
            )
            if local.usedPolarFallback { polarNotes.append(sample.label) }

            do {
                let fetched = try await AladhanClient().fetchTimes(
                    date: Date(), coordinate: coordinate, timeZone: zone,
                    method: method, madhab: madhab, highLatitudeRule: .automatic
                )
                print(sample.label)
                for prayer in Prayer.allCases {
                    guard let localTime = local.times[prayer] else {
                        print("  \(prayer.displayName.padded(to: 9)) —          (not calculated)")
                        continue
                    }
                    guard let apiTime = fetched.times[prayer] else {
                        print("  \(prayer.displayName.padded(to: 9)) \(clock.string(from: localTime))     (no api value)")
                        continue
                    }
                    let delta = Int((localTime.timeIntervalSince(apiTime) / 60).rounded())
                    allDeltas.append(abs(delta))
                    if showEveryPrayer {
                        print("  \(prayer.displayName.padded(to: 9)) \(clock.string(from: localTime))  \(clock.string(from: apiTime))  \(String(format: "%+4d", delta))m")
                    }
                }
            } catch {
                failures.append("\(sample.label): \(error.localizedDescription)")
                print("\(sample.label) FETCH FAILED: \(error.localizedDescription)")
            }
            print("")
        }

        if !polarNotes.isEmpty {
            print("Polar fallback applied for: \(polarNotes.joined(separator: ", "))")
        }

        guard !allDeltas.isEmpty else {
            print("No comparable samples (failures: \(failures.count)).")
            return
        }
        let within1 = allDeltas.filter { $0 <= 1 }.count
        let within2 = allDeltas.filter { $0 <= 2 }.count
        let worst = allDeltas.max() ?? 0
        let mean = Double(allDeltas.reduce(0, +)) / Double(allDeltas.count)
        print(String(format: "Samples: %d   mean |Δ|: %.2f min   ≤1min: %d/%d   ≤2min: %d/%d   worst: %d min   fetch failures: %d",
                     allDeltas.count, mean, within1, allDeltas.count, within2, allDeltas.count, worst, failures.count))
        if !failures.isEmpty {
            for failure in failures { print("  ! \(failure)") }
        }
    }

    static func clockFormatter(_ zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        // Seconds are useful when deriving a method's built-in tune offsets.
        formatter.dateFormat = ProcessInfo.processInfo.environment["PRAYERCTL_SECONDS"] == "1" ? "HH:mm:ss" : "HH:mm"
        formatter.timeZone = zone
        return formatter
    }
}

extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
