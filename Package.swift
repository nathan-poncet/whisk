// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Whisk",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Whisk",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WhiskTests",
            dependencies: ["Whisk"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
