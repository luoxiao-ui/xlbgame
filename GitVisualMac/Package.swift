// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitVisualMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GitVisualMac", targets: ["GitVisualMac"])
    ],
    targets: [
        .executableTarget(
            name: "GitVisualMac",
            dependencies: []
        )
    ]
)
