// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "WebPBenchmark",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WebPBench", targets: ["WebPBench"])
    ],
    dependencies: [
        .package(name: "Swift-WebP", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "WebPBench",
            dependencies: [
                .product(name: "WebP", package: "Swift-WebP")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
