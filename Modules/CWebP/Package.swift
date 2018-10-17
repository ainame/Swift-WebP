// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CWebP",
    pkgConfig: "libwebp",
    providers: [
        .brew(["webp"]),
    ],
    products: [
        .library(name: "CWebP", targets: ["CWebP"]),
    ],
    targets: [
        .systemLibrary(name: "CWebP"),
    ]
)
