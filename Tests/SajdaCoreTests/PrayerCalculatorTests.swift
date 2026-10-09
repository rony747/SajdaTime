import XCTest
@testable import SajdaCore

/// The assertions themselves live in `SajdaCoreSelfTest` so that the exact same
/// checks can also run via `sajdactl selftest` without a toolchain that can
/// build XCTest bundles.
final class PrayerCalculatorTests: XCTestCase {

    func testAllEngineInvariants() {
        let report = SajdaCoreSelfTest.report()
        XCTAssertTrue(
            report.passed,
            report.failures.map { "\($0.name): \($0.detail)" }.joined(separator: "\n")
        )
    }

    func testSelfTestActuallyCoversCases() {
        // Guards against the self-test quietly becoming a no-op. The previous
        // version asserted the failure list contained no entry called "noop",
        // which was true no matter what and so tested nothing.
        let report = SajdaCoreSelfTest.report()
        XCTAssertGreaterThanOrEqual(
            report.checksRun, 128,
            "the self-test ran only \(report.checksRun) checks; it has stopped covering the engine"
        )
    }
}
