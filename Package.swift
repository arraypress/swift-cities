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
