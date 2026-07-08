// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketTestSupport",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TrinketTestSupport",
            targets: ["TrinketTestSupport"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../TrinketPersistence"),
    ],
    targets: [
        .target(
            name: "TrinketTestSupport",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "TrinketPersistence",
            ]
        ),
    ]
)
