import Foundation

public enum AladhanError: Error, LocalizedError {
    case badStatus(Int)
    case malformedResponse
    case noTimes
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Aladhan returned HTTP \(code)."
        case .malformedResponse: return "Aladhan returned an unexpected response."
        case .noTimes: return "Aladhan returned no prayer times."
        case .transport(let message): return message
        }
    }
}

/// Fetches real prayer times from the Aladhan API.
///
/// Aladhan is the source of truth for "live" data; `PrayerCalculator` is the
/// offline fallback. Both speak the same method/madhab vocabulary so switching
/// between them does not change the numbers materially.
public struct AladhanClient: Sendable {
    public static let baseURL = URL(string: "https://api.aladhan.com/v1/timings")!

    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 25
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    /// Fetch one day of times.
    /// - Parameters:
    ///   - date: any instant within the target day; the calendar date is taken
    ///     on `timeZone`, which should be the user's display timezone.
    ///   - timeZone: timezone used to name the requested calendar date.
    public func fetchTimes(
        date: Date,
        coordinate: Coordinate,
        timeZone: TimeZone,
        method: CalculationMethod,
        madhab: Madhab,
        highLatitudeRule: HighLatitudeRule,
        adjustments: [String: Double] = [:],
        hijriAdjustment: Int = 0
    ) async throws -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        let dayString = String(format: "%02d-%02d-%04d", components.day ?? 1, components.month ?? 1, components.year ?? 2000)

        var items: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "method", value: String(method.aladhanId)),
            URLQueryItem(name: "school", value: String(madhab.aladhanValue)),
        ]
        if let latitudeMethod = highLatitudeRule.aladhanValue {
            items.append(URLQueryItem(name: "latitudeAdjustmentMethod", value: String(latitudeMethod)))
        }
        if !adjustments.isEmpty {
            // Aladhan expects nine comma-separated minute offsets in fixed order.
            let order = ["imsak", "fajr", "sunrise", "dhuhr", "asr", "maghrib", "sunset", "isha", "midnight"]
            let tune = order.map { String(Int(adjustments[$0] ?? 0)) }.joined(separator: ",")
            items.append(URLQueryItem(name: "tune", value: tune))
        }

        var urlComponents = URLComponents(url: Self.baseURL.appendingPathComponent(dayString), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = items

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: urlComponents.url!)
        } catch {
            throw AladhanError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AladhanError.badStatus(http.statusCode)
        }

        return try Self.parse(
            data: data,
            fallbackCoordinate: coordinate,
            fallbackMethod: method,
            requestedDay: date,
            timeZone: timeZone,
            hijriAdjustment: hijriAdjustment
        )
    }

    // MARK: - Response decoding

    private struct Envelope: Decodable {
        let code: Int
        let data: Payload

        struct Payload: Decodable {
            let timings: [String: String]
            let date: DateInfo?
            let meta: Meta?
        }

        struct DateInfo: Decodable {
            let hijri: Hijri?
            struct Hijri: Decodable {
                let day: String
                let year: String
                let month: Month
                struct Month: Decodable {
                    let number: Int
                    let en: String
                }
            }
        }

        struct Meta: Decodable {
            let timezone: String?
            let method: Method?
            struct Method: Decodable {
                let id: Int?
                let name: String?
            }
        }
    }

    static func parse(
        data: Data,
        fallbackCoordinate: Coordinate,
        fallbackMethod: CalculationMethod,
        requestedDay: Date,
        timeZone: TimeZone,
        hijriAdjustment: Int = 0
    ) throws -> PrayerTimes {
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            throw AladhanError.malformedResponse
        }
        guard envelope.code == 200 else {
            throw AladhanError.badStatus(envelope.code)
        }

        // Times come back as wall-clock strings in the *location's* timezone, so
        // they must be resolved there and only then displayed in the user's zone.
        let locationZone = envelope.data.meta?.timezone.flatMap(TimeZone.init(identifier:)) ?? timeZone
        var locationCalendar = Calendar(identifier: .gregorian)
        locationCalendar.timeZone = locationZone

        // Re-derive the calendar date inside the location's timezone.
        let dayComponents = locationCalendar.dateComponents([.day, .month, .year], from: requestedDay)
        guard let day = dayComponents.day, let month = dayComponents.month, let year = dayComponents.year else {
            throw AladhanError.malformedResponse
        }

        func resolve(_ raw: String?) -> Date? {
            guard let raw, let clock = Self.parseClock(raw) else { return nil }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = clock.hour
            components.minute = clock.minute
            return locationCalendar.date(from: components)
        }

        let timings = envelope.data.timings
        var times: [Prayer: Date] = [:]
        for prayer in Prayer.allCases {
            let key = Self.timingKey(for: prayer)
            if let value = resolve(timings[key]) { times[prayer] = value }
        }
        guard times[.fajr] != nil || times[.dhuhr] != nil else {
            throw AladhanError.noTimes
        }

        var displayCalendar = Calendar(identifier: .gregorian)
        displayCalendar.timeZone = timeZone

        var hijri: HijriDate?
        if let h = envelope.data.date?.hijri, let hDay = Int(h.day), let hYear = Int(h.year) {
            // Shift the returned date rather than recomputing it, so the
            // adjustment applies to live times too.
            if hijriAdjustment == 0 {
                hijri = HijriDate(day: hDay, monthIndex: h.month.number, year: hYear, adjustment: 0)
            } else if var base = locationCalendar.date(from: DateComponents(year: hYear, month: h.month.number, day: hDay)) {
                base = locationCalendar.date(byAdding: .day, value: hijriAdjustment, to: base) ?? base
                let shifted = locationCalendar.dateComponents([.day, .month, .year], from: base)
                hijri = HijriDate(
                    day: shifted.day ?? hDay,
                    monthIndex: shifted.month ?? h.month.number,
                    year: shifted.year ?? hYear,
                    adjustment: hijriAdjustment
                )
            }
        }

        return PrayerTimes(
            dayStart: displayCalendar.startOfDay(for: requestedDay),
            times: times,
            midnight: resolve(timings["Midnight"]),
            lastThird: resolve(timings["Lastthird"]),
            source: .api,
            methodName: envelope.data.meta?.method?.name ?? fallbackMethod.name,
            timeZoneIdentifier: timeZone.identifier,
            coordinate: fallbackCoordinate,
            hijri: hijri
        )
    }

    /// Aladhan's capitalisation is inconsistent across endpoints; map explicitly.
    private static func timingKey(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    /// Values look like `"05:38"` or `"05:38 (EEST)"`; take the leading clock.
    static func parseClock(_ raw: String) -> (hour: Int, minute: Int)? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let token = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        let parts = token.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1].prefix(2)) else { return nil }
        return (hour, minute)
    }
}
