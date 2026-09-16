// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketPersistence",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "TrinketPersistence",
            targets: ["TrinketPersistence"],
        ),
        .library(
            name: "TrinketPersistenceTestSupport",
            targets: ["TrinketPersistenceTestSupport"],
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
    ],
    targets: [
        .target(
            name: "TrinketPersistence",
            dependencies: ["TrinketCore", "TrinketContent"],
        ),
        .target(
            name: "TrinketPersistenceTestSupport",
            dependencies: ["TrinketPersistence", "TrinketContent", "TrinketCore"],
        ),
        .testTarget(
            name: "TrinketPersistenceTests",
            dependencies: [
                "TrinketPersistence",
                "TrinketCore",
                "TrinketContent",
                "TrinketPersistenceTestSupport",
            ],
        ),
    ],
)
