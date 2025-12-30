// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PocketBook2Capacities",
    platforms: [
        .macOS(.v14)  // macOS 14 for MenuBarExtra improvements
    ],
    products: [
        .library(name: "PocketBook2CapacitiesCore", targets: ["PocketBook2CapacitiesCore"]),
        .executable(name: "pocketbook2capacities", targets: ["PocketBook2Capacities"]),
        .executable(name: "PocketBook2CapacitiesApp", targets: ["PocketBook2CapacitiesApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Core library - shared business logic
        .target(
            name: "PocketBook2CapacitiesCore",
            dependencies: []
        ),
        // CLI executable
        .executableTarget(
            name: "PocketBook2Capacities",
            dependencies: [
                "PocketBook2CapacitiesCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        // Menu bar app
        .executableTarget(
            name: "PocketBook2CapacitiesApp",
            dependencies: [
                "PocketBook2CapacitiesCore",
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
