// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Whisk",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Whisk",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WhiskTests",
            dependencies: ["Whisk"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
