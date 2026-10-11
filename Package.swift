// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-cities",
    platforms: [
        .macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1),
    ],
    products: [
        .library(name: "Cities", targets: ["Cities"]),
    ],
    targets: [
        .target(name: "Cities", resources: [.copy("Resources")]),
        .testTarget(name: "CitiesTests", dependencies: ["Cities"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
