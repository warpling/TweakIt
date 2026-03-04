// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DevTweaks",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DevTweaks",
            targets: ["DevTweaks"]
        ),
    ],
    targets: [
        .target(
            name: "DevTweaks"
        ),
        .testTarget(
            name: "DevTweaksTests",
            dependencies: ["DevTweaks"]
        ),
    ]
)
