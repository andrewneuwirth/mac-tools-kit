// swift-tools-version:6.2
import PackageDescription

// The Mac Tools family's shared code: the design-system tokens as Swift, and the small
// pieces every tool otherwise copies (usage file, login item). Tools depend on it by path.
// MacToolsUpdates is separate so only the apps that ship Sparkle link it (docs/updates.md).
// macOS 15 is the floor of the oldest app that uses Kit (Burrow); the rest set 26 themselves.
let package = Package(
    name: "MacToolsKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MacToolsKit", targets: ["MacToolsKit"]),
        .library(name: "MacToolsUpdates", targets: ["MacToolsUpdates"]),
    ],
    dependencies: [
        // Keep in step with VERSION in tools/fetch-sparkle.sh.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .target(name: "MacToolsKit", path: "Sources/MacToolsKit",
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "MacToolsUpdates", dependencies: [.product(name: "Sparkle", package: "Sparkle")],
                path: "Sources/MacToolsUpdates", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "MacToolsKitTests", dependencies: ["MacToolsKit"], path: "Tests"),
    ]
)
