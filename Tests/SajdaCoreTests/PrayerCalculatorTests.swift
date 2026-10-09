import XCTest
@testable import SajdaCore

/// The assertions themselves live in `SajdaCoreSelfTest` so that the exact same
/// checks can also run via `sajdactl selftest` without a toolchain that can
/// build XCTest bundles.
final class PrayerCalculatorTests: XCTestCase {

    func testAllEngineInvariants() {
        let failures = SajdaCoreSelfTest.run()
        XCTAssertTrue(
            failures.isEmpty,
            failures.map { "\($0.name): \($0.detail)" }.joined(separator: "\n")
        )
    }

    func testSelfTestActuallyCoversCases() {
        // Guards against the self-test silently becoming a no-op.
        XCTAssertFalse(SajdaCoreSelfTest.run().contains { $0.name == "noop" })
    }
}
