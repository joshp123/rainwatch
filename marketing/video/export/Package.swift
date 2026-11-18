// swift-tools-version: 6.2
import PackageDescription

// Draws what the launch film shows of the app, from the app's own code (RainGraph at the repo's root).
// `app` is a link to the repo's root that render.sh makes: SwiftPM names a local package after its
// folder, and a clone or worktree can be called anything.
let package = Package(
    name: "film-export",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "app")],
    targets: [
        .executableTarget(name: "film-export", dependencies: [.product(name: "RainGraph", package: "app")],
                         // Its languages, so `-AppleLanguages (nl)` gets the app's Dutch words.
                         linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])]),
    ]
)
