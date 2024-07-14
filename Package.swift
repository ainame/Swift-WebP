// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebP",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(name: "WebP", targets: ["WebP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "WebP",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode")
            ]
        ),
        .testTarget(
            name: "WebPTests",
            dependencies: ["WebP"],
            resources: [
                .copy("Resources/jiro.jpg")
            ]
        )
    ]
)
