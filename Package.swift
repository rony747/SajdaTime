// swift-tools-version:5.9
import PackageDescription

// Note: tools-version 5.9 keeps the default language mode at Swift 5, which is
// what we want here (Swift 6 strict concurrency is unnecessary for an app that
// funnels all UI state through @MainActor observable objects).
let package = Package(
    name: "SajdaTime",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "SajdaCore", targets: ["SajdaCore"]),
        .executable(name: "SajdaTime", targets: ["SajdaTimeApp"]),
        .executable(name: "sajdactl", targets: ["SajdaTimeCtl"]),
    ],
    targets: [
        // Pure logic: astronomy, methods, API client, settings. No UI, fully testable.
        .target(name: "SajdaCore"),
        // The SwiftUI menu bar application.
        .executableTarget(name: "SajdaTimeApp", dependencies: ["SajdaCore"]),
        // Command line harness used to verify calculations against the live API.
        .executableTarget(name: "SajdaTimeCtl", dependencies: ["SajdaCore"]),
        .testTarget(name: "SajdaCoreTests", dependencies: ["SajdaCore"]),
    ]
)
