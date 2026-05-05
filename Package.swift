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
    targets: [
        .target(
            name: "PageLumenCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "PageLumen",
            dependencies: ["PageLumenCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PageLumenCoreTests",
            dependencies: ["PageLumenCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
