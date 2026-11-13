// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RainWatchMockups",
    platforms: [.watchOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RainGraph", targets: ["RainGraph"]),
    ],
    targets: [
        .target(name: "RainGraph"),
        .executableTarget(name: "render-mockups", dependencies: ["RainGraph"]),
        .executableTarget(name: "copy-check", dependencies: ["RainGraph"]),
    ]
)
