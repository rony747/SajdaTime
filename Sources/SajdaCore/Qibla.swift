import Foundation

/// Direction and distance to the Kaaba.
///
/// Kept in the core module so the bearing can be asserted in tests; a compass
/// that quietly points the wrong way would be worse than no compass.
public enum Qibla {

    /// The Kaaba, Makkah.
    public static let kaaba = Coordinate(latitude: 21.4225, longitude: 39.8262)

    /// Great-circle initial bearing from `origin` to the Kaaba, in degrees
    /// clockwise from true north (0...360).
    public static func bearing(from origin: Coordinate) -> Double {
        let phi1 = origin.latitude * .pi / 180
        let phi2 = kaaba.latitude * .pi / 180
        let deltaLambda = (kaaba.longitude - origin.longitude) * .pi / 180

        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// Great-circle distance to the Kaaba in kilometres.
    public static func distance(from origin: Coordinate) -> Double {
        let radius = 6371.0088
        let phi1 = origin.latitude * .pi / 180
        let phi2 = kaaba.latitude * .pi / 180
        let deltaPhi = (kaaba.latitude - origin.latitude) * .pi / 180
        let deltaLambda = (kaaba.longitude - origin.longitude) * .pi / 180

        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return 2 * radius * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Compass point for a bearing, e.g. "WSW".
    public static func compassPoint(for bearing: Double) -> String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((bearing / 22.5).rounded()) % 16
        return points[(index + 16) % 16]
    }
}
