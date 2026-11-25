// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SentinelKit",
    platforms: [
        .iOS(.v15),
        // macOS only lets `swift test` run on the host; the SDK targets iOS.
        .macOS(.v12),
    ],
    products: [
        .library(name: "SentinelKit", targets: ["SentinelKit"]),
    ],
    targets: [
        .target(
            name: "SentinelKit",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "SentinelKitTests",
            dependencies: ["SentinelKit"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
