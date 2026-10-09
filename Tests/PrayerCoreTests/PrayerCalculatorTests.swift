import XCTest
@testable import PrayerCore

/// The assertions themselves live in `PrayerCoreSelfTest` so that the exact same
/// checks can also run via `prayerbarctl selftest` without a toolchain that can
/// build XCTest bundles.
final class PrayerCalculatorTests: XCTestCase {

    func testAllEngineInvariants() {
        let failures = PrayerCoreSelfTest.run()
        XCTAssertTrue(
            failures.isEmpty,
            failures.map { "\($0.name): \($0.detail)" }.joined(separator: "\n")
        )
    }

    func testSelfTestActuallyCoversCases() {
        // Guards against the self-test silently becoming a no-op.
        XCTAssertFalse(PrayerCoreSelfTest.run().contains { $0.name == "noop" })
    }
}
