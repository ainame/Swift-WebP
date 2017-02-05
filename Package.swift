import PackageDescription

let package = Package(
    name: "WebP",
    dependencies: [
        .Package(url: "https://github.com/ainame/CWebP.git", majorVersion: 0, minor: 6)
    ]
)
