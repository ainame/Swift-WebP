import PackageDescription

let package = Package(
    name: "CWebP"
    providers: [
        .Brew(installName: "webp"),
        .Apt(installName: "libwebp")
    ]
)
