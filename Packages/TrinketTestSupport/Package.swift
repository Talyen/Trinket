// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketTestSupport",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
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
    ],
    targets: [
        .target(
            name: "TrinketTestSupport",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
            ]
        ),
    ]
)
