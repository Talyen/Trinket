// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketPersistence",
    platforms: [
        .iOS(.v26),
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
        .package(path: "../TrinketTestSupport"),
    ],
    targets: [
        .target(
            name: "TrinketPersistence",
            dependencies: ["TrinketCore", "TrinketContent"]
        ),
        .testTarget(
            name: "TrinketPersistenceTests",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
            ]
        ),
    ]
)
