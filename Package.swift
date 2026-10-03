// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalizedTranslate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalizedTranslate", targets: ["LocalizedTranslate"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LocalizedTranslate",
            path: "LocalizedTranslate",
            exclude: ["Assets.xcassets", "LocalizedTranslate.entitlements"]
        )
    ]
)
