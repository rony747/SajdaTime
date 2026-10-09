import Foundation
import CoreLocation

/// Device heading, when the machine actually has a magnetometer.
///
/// Macs do not. `CLLocationManager.headingAvailable` returns false, and a
/// compass drawn without one would point at nothing — so the Qibla feature is
/// hidden entirely rather than shown as a decoration that cannot work.
@MainActor
final class HeadingService: NSObject, ObservableObject {

    /// True only when a real heading can be delivered.
    let isAvailable: Bool

    /// Degrees clockwise from true north.
    @Published private(set) var heading: Double = 0

    private let manager = CLLocationManager()

    override init() {
        // Development hook: pretend a magnetometer exists so the compass can be
        // laid out and checked on a machine that has none.
        if let raw = ProcessInfo.processInfo.environment["SAJDA_FAKE_HEADING"],
           let value = Double(raw) {
            isAvailable = true
            super.init()
            heading = value
            return
        }

        isAvailable = CLLocationManager.headingAvailable()
        super.init()

        guard isAvailable else { return }
        manager.delegate = self
        manager.headingFilter = 1
        manager.startUpdatingHeading()
    }
}

extension HeadingService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // A negative accuracy means the reading is invalid.
        guard newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = value }
    }
}
