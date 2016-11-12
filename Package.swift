import PackageDescription

let package = Package(
    name: "WebP",
    dependencies: [
        .Package(url: "Modules/CWebP", majorVersion: 0)
    ],
)
