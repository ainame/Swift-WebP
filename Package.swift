// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebP",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "WebP", targets: ["WebP"]),
        .executable(name: "WebPBench", targets: ["WebPBench"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.58.0"),
    ],
    targets: [
        .target(
            name: "WebP",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode")
            ],
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "WebPBench",
            dependencies: ["WebP"]
        ),
        .testTarget(
            name: "WebPTests",
            dependencies: ["WebP"],
            resources: [
                .copy("Resources/jiro.jpg")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
