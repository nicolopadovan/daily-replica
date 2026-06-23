// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DailyReplica",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DailyReplicaCore",
            targets: ["DailyReplicaCore"]
        ),
        .executable(
            name: "DailyReplica",
            targets: ["DailyReplica"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "DailyReplicaCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "DailyReplica",
            dependencies: [
                "DailyReplicaCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "DailyReplicaCoreTests",
            dependencies: ["DailyReplicaCore"]
        ),
        .testTarget(
            name: "DailyReplicaTests",
            dependencies: ["DailyReplica"]
        )
    ]
)
