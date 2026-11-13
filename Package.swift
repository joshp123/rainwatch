// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RainWatchMockups",
    platforms: [.watchOS(.v11), .macOS(.v15)],
    products: [
        .library(name: "RainComplication", targets: ["RainComplication"]),
    ],
    targets: [
        .target(name: "RainGraph"),
        .target(name: "RainComplication", dependencies: ["RainGraph"]),
        .executableTarget(name: "render-mockups", dependencies: ["RainGraph"]),
    ]
)
