import Foundation
import CoreLocation

/// Wraps CoreLocation for one-shot "where am I" lookups.
///
/// Deliberately one-shot: the app needs a position to compute prayer times, not
/// continuous tracking, so it never starts `startUpdatingLocation`.
@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isLocating = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Called on the main actor with the resolved position and optional placemark.
    var onResolved: ((CLLocation, CLPlacemark?) -> Void)?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .authorizedAlways
    }

    /// Ask for permission if needed and then request a single fix.
    func detectLocation() {
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            // The delegate callback continues the flow once the user answers.
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access is off. Turn it on in System Settings › Privacy & Security › Location Services."
        default:
            requestFix()
        }
    }

    private func requestFix() {
        isLocating = true
        manager.requestLocation()
    }

    private func fail(_ message: String) {
        isLocating = false
        errorMessage = message
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorized || status == .authorizedAlways {
                self.requestFix()
            } else if status == .denied || status == .restricted {
                self.fail("Location access is off. Turn it on in System Settings › Privacy & Security › Location Services.")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Reverse geocoding is best-effort: the coordinate alone is enough to
            // compute times, so a geocoder failure must not fail the detection.
            let placemark = try? await self.geocoder.reverseGeocodeLocation(location).first
            self.isLocating = false
            self.errorMessage = nil
            self.onResolved?(location, placemark)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        Task { @MainActor in
            // kCLErrorDomain 0 is `locationUnknown`: usually a transient failure
            // to get a fix, so it is worth phrasing as a retry rather than a fault.
            if nsError.domain == kCLErrorDomain, nsError.code == CLError.locationUnknown.rawValue {
                self.fail("Couldn't get a position yet. Try again in a moment.")
            } else {
                self.fail(nsError.localizedDescription)
            }
        }
    }
}
