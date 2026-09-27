// swift-tools-version:6.2
import PackageDescription
let package = Package(
    name: "Consumer",
    platforms: [.macOS(.v11)],
    dependencies: [.package(path: "../../..")],
    targets: [.executableTarget(name: "Consumer", dependencies: [.product(name: "WebP", package: "Swift-WebP")])],
    swiftLanguageModes: [.v6]
)
