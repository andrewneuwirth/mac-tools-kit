// swift-tools-version:6.2
import PackageDescription

// The Mac Tools family's shared code: the design-system tokens as Swift, and the small
// pieces every tool otherwise copies (usage file, login item). Tools depend on it by path.
let package = Package(
    name: "MacToolsKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "MacToolsKit", targets: ["MacToolsKit"])],
    targets: [
        .target(name: "MacToolsKit", path: "Sources/MacToolsKit",
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "MacToolsKitTests", dependencies: ["MacToolsKit"], path: "Tests"),
    ]
)
