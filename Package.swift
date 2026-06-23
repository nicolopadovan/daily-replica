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
    targets: [
        .target(
            name: "DailyReplicaCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "DailyReplica",
            dependencies: ["DailyReplicaCore"],
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
