// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Whisk",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Whisk", targets: ["Whisk"]),
        .library(name: "WhiskKernel", targets: ["WhiskKernel"]),
    ],
    targets: [
        .target(
            name: "WhiskKernel",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "HistoryStoreFile",
            dependencies: ["WhiskKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "PasteboardAppKit",
            dependencies: ["WhiskKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Whisk",
            dependencies: ["WhiskKernel", "HistoryStoreFile", "PasteboardAppKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WhiskKernelTests",
            dependencies: ["WhiskKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HistoryStoreFileTests",
            dependencies: ["HistoryStoreFile", "WhiskKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
