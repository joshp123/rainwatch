// swift-tools-version: 6.2
import PackageDescription

// Draws what the launch film shows of the app, from the app's own code (RainGraph at the repo's root).
let package = Package(
    name: "film-export",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../..")],
    targets: [
        .executableTarget(name: "film-export", dependencies: [.product(name: "RainGraph", package: "buienradar-apple-watch")],
                         // Its languages, so `-AppleLanguages (nl)` gets the app's Dutch words.
                         linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])]),
    ]
)
