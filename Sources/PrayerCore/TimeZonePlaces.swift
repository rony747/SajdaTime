import Foundation

/// A representative city for a timezone, used to seed a sensible default
/// location before the user's real position is known.
public struct Place: Sendable, Equatable {
    public let city: String
    public let countryCode: String
    public let latitude: Double
    public let longitude: Double

    public init(city: String, countryCode: String, latitude: Double, longitude: Double) {
        self.city = city
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Maps IANA timezone identifiers to a representative city.
///
/// This exists because a hard-coded default location is wrong for almost
/// everyone: an app that ships with Istanbul's coordinates shows Istanbul's
/// prayer times to a user in Dhaka. Seeding from the system timezone means the
/// first launch is already in the right part of the world, and nothing is
/// displayed until the real position resolves.
public enum TimeZonePlaces {

    public static func place(forTimeZoneIdentifier identifier: String) -> Place? {
        if let exact = table[identifier] { return exact }
        // Fall back to a region match, e.g. "Europe/Amsterdam" for a zone we
        // do not list but whose region we do.
        if let slash = identifier.firstIndex(of: "/") {
            let region = String(identifier[identifier.startIndex..<slash])
            if let regional = regionalFallback[region] { return regional }
        }
        return nil
    }

    private static let regionalFallback: [String: Place] = [
        "Africa": Place(city: "Cairo", countryCode: "EG", latitude: 30.0444, longitude: 31.2357),
        "America": Place(city: "New York", countryCode: "US", latitude: 40.7128, longitude: -74.0060),
        "Antarctica": Place(city: "McMurdo", countryCode: "AQ", latitude: -77.8419, longitude: 166.6863),
        "Arctic": Place(city: "Longyearbyen", countryCode: "SJ", latitude: 78.2232, longitude: 15.6267),
        "Asia": Place(city: "Karachi", countryCode: "PK", latitude: 24.8607, longitude: 67.0011),
        "Atlantic": Place(city: "Lisbon", countryCode: "PT", latitude: 38.7223, longitude: -9.1393),
        "Australia": Place(city: "Sydney", countryCode: "AU", latitude: -33.8688, longitude: 151.2093),
        "Europe": Place(city: "London", countryCode: "GB", latitude: 51.5072, longitude: -0.1276),
        "Indian": Place(city: "Port Louis", countryCode: "MU", latitude: -20.1609, longitude: 57.5012),
        "Pacific": Place(city: "Auckland", countryCode: "NZ", latitude: -36.8485, longitude: 174.7633),
    ]

    /// Representative cities for the zones most users are likely to be in.
    private static let table: [String: Place] = [
        // South and South-East Asia
        "Asia/Dhaka": Place(city: "Dhaka", countryCode: "BD", latitude: 23.8103, longitude: 90.4125),
        "Asia/Kolkata": Place(city: "Kolkata", countryCode: "IN", latitude: 22.5726, longitude: 88.3639),
        "Asia/Calcutta": Place(city: "Kolkata", countryCode: "IN", latitude: 22.5726, longitude: 88.3639),
        "Asia/Karachi": Place(city: "Karachi", countryCode: "PK", latitude: 24.8607, longitude: 67.0011),
        "Asia/Lahore": Place(city: "Lahore", countryCode: "PK", latitude: 31.5204, longitude: 74.3587),
        "Asia/Kabul": Place(city: "Kabul", countryCode: "AF", latitude: 34.5553, longitude: 69.2075),
        "Asia/Colombo": Place(city: "Colombo", countryCode: "LK", latitude: 6.9271, longitude: 79.8612),
        "Asia/Kathmandu": Place(city: "Kathmandu", countryCode: "NP", latitude: 27.7172, longitude: 85.3240),
        "Asia/Yangon": Place(city: "Yangon", countryCode: "MM", latitude: 16.8661, longitude: 96.1951),
        "Asia/Bangkok": Place(city: "Bangkok", countryCode: "TH", latitude: 13.7563, longitude: 100.5018),
        "Asia/Ho_Chi_Minh": Place(city: "Ho Chi Minh City", countryCode: "VN", latitude: 10.8231, longitude: 106.6297),
        "Asia/Hanoi": Place(city: "Hanoi", countryCode: "VN", latitude: 21.0278, longitude: 105.8342),
        "Asia/Phnom_Penh": Place(city: "Phnom Penh", countryCode: "KH", latitude: 11.5564, longitude: 104.9282),
        "Asia/Kuala_Lumpur": Place(city: "Kuala Lumpur", countryCode: "MY", latitude: 3.1390, longitude: 101.6869),
        "Asia/Singapore": Place(city: "Singapore", countryCode: "SG", latitude: 1.3521, longitude: 103.8198),
        "Asia/Jakarta": Place(city: "Jakarta", countryCode: "ID", latitude: -6.2088, longitude: 106.8456),
        "Asia/Makassar": Place(city: "Makassar", countryCode: "ID", latitude: -5.1477, longitude: 119.4327),
        "Asia/Jayapura": Place(city: "Jayapura", countryCode: "ID", latitude: -2.5916, longitude: 140.6690),
        "Asia/Manila": Place(city: "Manila", countryCode: "PH", latitude: 14.5995, longitude: 120.9842),
        "Asia/Brunei": Place(city: "Bandar Seri Begawan", countryCode: "BN", latitude: 4.9031, longitude: 114.9398),
        "Asia/Taipei": Place(city: "Taipei", countryCode: "TW", latitude: 25.0330, longitude: 121.5654),
        "Asia/Hong_Kong": Place(city: "Hong Kong", countryCode: "HK", latitude: 22.3193, longitude: 114.1694),
        "Asia/Shanghai": Place(city: "Shanghai", countryCode: "CN", latitude: 31.2304, longitude: 121.4737),
        "Asia/Urumqi": Place(city: "Ürümqi", countryCode: "CN", latitude: 43.8256, longitude: 87.6168),
        "Asia/Seoul": Place(city: "Seoul", countryCode: "KR", latitude: 37.5665, longitude: 126.9780),
        "Asia/Tokyo": Place(city: "Tokyo", countryCode: "JP", latitude: 35.6762, longitude: 139.6503),
        "Asia/Osaka": Place(city: "Osaka", countryCode: "JP", latitude: 34.6937, longitude: 135.5023),

        // Middle East and Central Asia
        "Asia/Riyadh": Place(city: "Riyadh", countryCode: "SA", latitude: 24.7136, longitude: 46.6753),
        "Asia/Jeddah": Place(city: "Jeddah", countryCode: "SA", latitude: 21.4858, longitude: 39.1925),
        "Asia/Mecca": Place(city: "Makkah", countryCode: "SA", latitude: 21.4225, longitude: 39.8262),
        "Asia/Dubai": Place(city: "Dubai", countryCode: "AE", latitude: 25.2048, longitude: 55.2708),
        "Asia/Muscat": Place(city: "Muscat", countryCode: "OM", latitude: 23.5880, longitude: 58.3829),
        "Asia/Qatar": Place(city: "Doha", countryCode: "QA", latitude: 25.2854, longitude: 51.5310),
        "Asia/Kuwait": Place(city: "Kuwait City", countryCode: "KW", latitude: 29.3759, longitude: 47.9774),
        "Asia/Bahrain": Place(city: "Manama", countryCode: "BH", latitude: 26.2285, longitude: 50.5860),
        "Asia/Baghdad": Place(city: "Baghdad", countryCode: "IQ", latitude: 33.3152, longitude: 44.3661),
        "Asia/Tehran": Place(city: "Tehran", countryCode: "IR", latitude: 35.6892, longitude: 51.3890),
        "Asia/Amman": Place(city: "Amman", countryCode: "JO", latitude: 31.9454, longitude: 35.9284),
        "Asia/Beirut": Place(city: "Beirut", countryCode: "LB", latitude: 33.8938, longitude: 35.5018),
        "Asia/Damascus": Place(city: "Damascus", countryCode: "SY", latitude: 33.5138, longitude: 36.2765),
        "Asia/Jerusalem": Place(city: "Jerusalem", countryCode: "IL", latitude: 31.7683, longitude: 35.2137),
        "Asia/Tel_Aviv": Place(city: "Tel Aviv", countryCode: "IL", latitude: 32.0853, longitude: 34.7818),
        "Asia/Gaza": Place(city: "Gaza", countryCode: "PS", latitude: 31.5017, longitude: 34.4668),
        "Asia/Hebron": Place(city: "Hebron", countryCode: "PS", latitude: 31.5326, longitude: 35.0998),
        "Asia/Aden": Place(city: "Aden", countryCode: "YE", latitude: 12.7855, longitude: 45.0187),
        "Asia/Baku": Place(city: "Baku", countryCode: "AZ", latitude: 40.4093, longitude: 49.8671),
        "Asia/Tbilisi": Place(city: "Tbilisi", countryCode: "GE", latitude: 41.7151, longitude: 44.8271),
        "Asia/Yerevan": Place(city: "Yerevan", countryCode: "AM", latitude: 40.1792, longitude: 44.4991),
        "Asia/Tashkent": Place(city: "Tashkent", countryCode: "UZ", latitude: 41.2995, longitude: 69.2401),
        "Asia/Almaty": Place(city: "Almaty", countryCode: "KZ", latitude: 43.2220, longitude: 76.8512),
        "Asia/Bishkek": Place(city: "Bishkek", countryCode: "KG", latitude: 42.8746, longitude: 74.5698),
        "Asia/Dushanbe": Place(city: "Dushanbe", countryCode: "TJ", latitude: 38.5598, longitude: 68.7870),
        "Asia/Ashgabat": Place(city: "Ashgabat", countryCode: "TM", latitude: 37.9601, longitude: 58.3261),

        // Europe
        "Europe/Istanbul": Place(city: "Istanbul", countryCode: "TR", latitude: 41.0082, longitude: 28.9784),
        "Europe/London": Place(city: "London", countryCode: "GB", latitude: 51.5072, longitude: -0.1276),
        "Europe/Dublin": Place(city: "Dublin", countryCode: "IE", latitude: 53.3498, longitude: -6.2603),
        "Europe/Paris": Place(city: "Paris", countryCode: "FR", latitude: 48.8566, longitude: 2.3522),
        "Europe/Brussels": Place(city: "Brussels", countryCode: "BE", latitude: 50.8503, longitude: 4.3517),
        "Europe/Amsterdam": Place(city: "Amsterdam", countryCode: "NL", latitude: 52.3676, longitude: 4.9041),
        "Europe/Berlin": Place(city: "Berlin", countryCode: "DE", latitude: 52.5200, longitude: 13.4050),
        "Europe/Vienna": Place(city: "Vienna", countryCode: "AT", latitude: 48.2082, longitude: 16.3738),
        "Europe/Zurich": Place(city: "Zurich", countryCode: "CH", latitude: 47.3769, longitude: 8.5417),
        "Europe/Rome": Place(city: "Rome", countryCode: "IT", latitude: 41.9028, longitude: 12.4964),
        "Europe/Madrid": Place(city: "Madrid", countryCode: "ES", latitude: 40.4168, longitude: -3.7038),
        "Europe/Lisbon": Place(city: "Lisbon", countryCode: "PT", latitude: 38.7223, longitude: -9.1393),
        "Europe/Stockholm": Place(city: "Stockholm", countryCode: "SE", latitude: 59.3293, longitude: 18.0686),
        "Europe/Oslo": Place(city: "Oslo", countryCode: "NO", latitude: 59.9139, longitude: 10.7522),
        "Europe/Copenhagen": Place(city: "Copenhagen", countryCode: "DK", latitude: 55.6761, longitude: 12.5683),
        "Europe/Helsinki": Place(city: "Helsinki", countryCode: "FI", latitude: 60.1699, longitude: 24.9384),
        "Europe/Warsaw": Place(city: "Warsaw", countryCode: "PL", latitude: 52.2297, longitude: 21.0122),
        "Europe/Prague": Place(city: "Prague", countryCode: "CZ", latitude: 50.0755, longitude: 14.4378),
        "Europe/Budapest": Place(city: "Budapest", countryCode: "HU", latitude: 47.4979, longitude: 19.0402),
        "Europe/Bucharest": Place(city: "Bucharest", countryCode: "RO", latitude: 44.4268, longitude: 26.1025),
        "Europe/Sofia": Place(city: "Sofia", countryCode: "BG", latitude: 42.6977, longitude: 23.3219),
        "Europe/Athens": Place(city: "Athens", countryCode: "GR", latitude: 37.9838, longitude: 23.7275),
        "Europe/Moscow": Place(city: "Moscow", countryCode: "RU", latitude: 55.7558, longitude: 37.6173),
        "Europe/Kyiv": Place(city: "Kyiv", countryCode: "UA", latitude: 50.4501, longitude: 30.5234),
        "Europe/Kiev": Place(city: "Kyiv", countryCode: "UA", latitude: 50.4501, longitude: 30.5234),
        "Europe/Belgrade": Place(city: "Belgrade", countryCode: "RS", latitude: 44.7866, longitude: 20.4489),
        "Europe/Zagreb": Place(city: "Zagreb", countryCode: "HR", latitude: 45.8150, longitude: 15.9819),
        "Europe/Sarajevo": Place(city: "Sarajevo", countryCode: "BA", latitude: 43.8563, longitude: 18.4131),
        "Europe/Tirane": Place(city: "Tirana", countryCode: "AL", latitude: 41.3275, longitude: 19.8187),
        "Europe/Skopje": Place(city: "Skopje", countryCode: "MK", latitude: 41.9973, longitude: 21.4280),

        // Africa
        "Africa/Cairo": Place(city: "Cairo", countryCode: "EG", latitude: 30.0444, longitude: 31.2357),
        "Africa/Casablanca": Place(city: "Casablanca", countryCode: "MA", latitude: 33.5731, longitude: -7.5898),
        "Africa/Algiers": Place(city: "Algiers", countryCode: "DZ", latitude: 36.7538, longitude: 3.0588),
        "Africa/Tunis": Place(city: "Tunis", countryCode: "TN", latitude: 36.8065, longitude: 10.1815),
        "Africa/Tripoli": Place(city: "Tripoli", countryCode: "LY", latitude: 32.8872, longitude: 13.1913),
        "Africa/Khartoum": Place(city: "Khartoum", countryCode: "SD", latitude: 15.5007, longitude: 32.5599),
        "Africa/Lagos": Place(city: "Lagos", countryCode: "NG", latitude: 6.5244, longitude: 3.3792),
        "Africa/Accra": Place(city: "Accra", countryCode: "GH", latitude: 5.6037, longitude: -0.1870),
        "Africa/Nairobi": Place(city: "Nairobi", countryCode: "KE", latitude: -1.2921, longitude: 36.8219),
        "Africa/Addis_Ababa": Place(city: "Addis Ababa", countryCode: "ET", latitude: 9.0320, longitude: 38.7469),
        "Africa/Dakar": Place(city: "Dakar", countryCode: "SN", latitude: 14.7167, longitude: -17.4677),
        "Africa/Bamako": Place(city: "Bamako", countryCode: "ML", latitude: 12.6392, longitude: -8.0029),
        "Africa/Johannesburg": Place(city: "Johannesburg", countryCode: "ZA", latitude: -26.2041, longitude: 28.0473),
        "Africa/Cape_Town": Place(city: "Cape Town", countryCode: "ZA", latitude: -33.9249, longitude: 18.4241),
        "Africa/Mogadishu": Place(city: "Mogadishu", countryCode: "SO", latitude: 2.0469, longitude: 45.3182),
        "Africa/Kampala": Place(city: "Kampala", countryCode: "UG", latitude: 0.3476, longitude: 32.5825),
        "Africa/Dar_es_Salaam": Place(city: "Dar es Salaam", countryCode: "TZ", latitude: -6.7924, longitude: 39.2083),
        "Africa/Nouakchott": Place(city: "Nouakchott", countryCode: "MR", latitude: 18.0735, longitude: -15.9582),

        // Americas
        "America/New_York": Place(city: "New York", countryCode: "US", latitude: 40.7128, longitude: -74.0060),
        "America/Chicago": Place(city: "Chicago", countryCode: "US", latitude: 41.8781, longitude: -87.6298),
        "America/Denver": Place(city: "Denver", countryCode: "US", latitude: 39.7392, longitude: -104.9903),
        "America/Phoenix": Place(city: "Phoenix", countryCode: "US", latitude: 33.4484, longitude: -112.0740),
        "America/Los_Angeles": Place(city: "Los Angeles", countryCode: "US", latitude: 34.0522, longitude: -118.2437),
        "America/Anchorage": Place(city: "Anchorage", countryCode: "US", latitude: 61.2181, longitude: -149.9003),
        "America/Detroit": Place(city: "Detroit", countryCode: "US", latitude: 42.3314, longitude: -83.0458),
        "America/Indiana/Indianapolis": Place(city: "Indianapolis", countryCode: "US", latitude: 39.7684, longitude: -86.1581),
        "America/Toronto": Place(city: "Toronto", countryCode: "CA", latitude: 43.6532, longitude: -79.3832),
        "America/Vancouver": Place(city: "Vancouver", countryCode: "CA", latitude: 49.2827, longitude: -123.1207),
        "America/Edmonton": Place(city: "Edmonton", countryCode: "CA", latitude: 53.5461, longitude: -113.4938),
        "America/Montreal": Place(city: "Montréal", countryCode: "CA", latitude: 45.5017, longitude: -73.5673),
        "America/Mexico_City": Place(city: "Mexico City", countryCode: "MX", latitude: 19.4326, longitude: -99.1332),
        "America/Bogota": Place(city: "Bogotá", countryCode: "CO", latitude: 4.7110, longitude: -74.0721),
        "America/Lima": Place(city: "Lima", countryCode: "PE", latitude: -12.0464, longitude: -77.0428),
        "America/Santiago": Place(city: "Santiago", countryCode: "CL", latitude: -33.4489, longitude: -70.6693),
        "America/Sao_Paulo": Place(city: "São Paulo", countryCode: "BR", latitude: -23.5505, longitude: -46.6333),
        "America/Argentina/Buenos_Aires": Place(city: "Buenos Aires", countryCode: "AR", latitude: -34.6037, longitude: -58.3816),
        "America/Caracas": Place(city: "Caracas", countryCode: "VE", latitude: 10.4806, longitude: -66.9036),

        // Oceania
        "Australia/Sydney": Place(city: "Sydney", countryCode: "AU", latitude: -33.8688, longitude: 151.2093),
        "Australia/Melbourne": Place(city: "Melbourne", countryCode: "AU", latitude: -37.8136, longitude: 144.9631),
        "Australia/Brisbane": Place(city: "Brisbane", countryCode: "AU", latitude: -27.4698, longitude: 153.0251),
        "Australia/Perth": Place(city: "Perth", countryCode: "AU", latitude: -31.9523, longitude: 115.8613),
        "Australia/Adelaide": Place(city: "Adelaide", countryCode: "AU", latitude: -34.9285, longitude: 138.6007),
        "Pacific/Auckland": Place(city: "Auckland", countryCode: "NZ", latitude: -36.8485, longitude: 174.7633),
        "Pacific/Fiji": Place(city: "Suva", countryCode: "FJ", latitude: -18.1416, longitude: 178.4419),
    ]
}
