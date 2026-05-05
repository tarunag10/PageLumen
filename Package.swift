// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SightlineReader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SightlineCore", targets: ["SightlineCore"]),
        .executable(name: "SightlineReader", targets: ["SightlineReader"])
    ],
    targets: [
        .target(
            name: "SightlineCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "SightlineReader",
            dependencies: ["SightlineCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SightlineCoreTests",
            dependencies: ["SightlineCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
