// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SpeakAway",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SpeakAway", targets: ["SpeakAway"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        // Pure logic, no AppKit: tested on its own.
        .target(name: "SpeakAwayCore"),
        .executableTarget(
            name: "SpeakAway",
            dependencies: ["SpeakAwayCore", .product(name: "WhisperKit", package: "WhisperKit")]
        ),
        .testTarget(name: "SpeakAwayCoreTests", dependencies: ["SpeakAwayCore"]),
    ]
)
