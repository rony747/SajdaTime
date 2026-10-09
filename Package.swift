// swift-tools-version:5.9
import PackageDescription

// Note: tools-version 5.9 keeps the default language mode at Swift 5, which is
// what we want here (Swift 6 strict concurrency is unnecessary for an app that
// funnels all UI state through @MainActor observable objects).
let package = Package(
    name: "PrayerBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PrayerCore", targets: ["PrayerCore"]),
        .executable(name: "PrayerBar", targets: ["PrayerBarApp"]),
        .executable(name: "prayerbarctl", targets: ["PrayerBarCtl"]),
    ],
    targets: [
        // Pure logic: astronomy, methods, API client, settings. No UI, fully testable.
        .target(name: "PrayerCore"),
        // The SwiftUI menu bar application.
        .executableTarget(name: "PrayerBarApp", dependencies: ["PrayerCore"]),
        // Command line harness used to verify calculations against the live API.
        .executableTarget(name: "PrayerBarCtl", dependencies: ["PrayerCore"]),
        .testTarget(name: "PrayerCoreTests", dependencies: ["PrayerCore"]),
    ]
)
