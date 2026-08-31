// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pasteur",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pasteur", targets: ["Pasteur"]),
        .library(name: "PasteurKernel", targets: ["PasteurKernel"]),
    ],
    targets: [
        .target(
            name: "PasteurKernel",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "HistoryStoreFile",
            dependencies: ["PasteurKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "PasteboardAppKit",
            dependencies: ["PasteurKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Pasteur",
            dependencies: ["PasteurKernel", "HistoryStoreFile", "PasteboardAppKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PasteurKernelTests",
            dependencies: ["PasteurKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HistoryStoreFileTests",
            dependencies: ["HistoryStoreFile", "PasteurKernel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
