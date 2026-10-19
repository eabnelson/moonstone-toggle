// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Moonstone",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Moonstone", targets: ["Moonstone"])],
    targets: [
        .target(name: "MoonstoneCore"),
        .executableTarget(name: "Moonstone", dependencies: ["MoonstoneCore"],
                          linkerSettings: [.linkedFramework("AppKit")]),
        .testTarget(name: "MoonstoneCoreTests", dependencies: ["MoonstoneCore"])
    ]
)
