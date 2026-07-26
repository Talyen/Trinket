// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketPersistence",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TrinketPersistence",
            targets: ["TrinketPersistence"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
    ],
    targets: [
        .target(
            name: "TrinketPersistence",
            dependencies: ["TrinketCore", "TrinketContent"]
        ),
        .testTarget(
            name: "TrinketPersistenceTests",
            dependencies: [
                "TrinketPersistence",
                "TrinketCore",
                "TrinketContent",
            ]
        ),
    ]
)
