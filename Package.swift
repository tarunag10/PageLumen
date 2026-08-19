// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PageLumen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PageLumenCore", targets: ["PageLumenCore"]),
        .executable(name: "PageLumen", targets: ["PageLumen"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "PageLumenCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "PageLumen",
            dependencies: [
                "PageLumenCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PageLumenCoreTests",
            dependencies: [
                "PageLumenCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PageLumenTests",
            dependencies: [
                "PageLumen",
                "PageLumenCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
