// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenshotIndexing",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "ScreenshotIndexing",
            targets: ["ScreenshotIndexing"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ScreenshotIndexing",
            path: "Sources/ScreenshotIndexing",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Vision"),
                .linkedFramework("FoundationModels"),
                .linkedFramework("AppKit"),
                .linkedFramework("Quartz"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "ScreenshotIndexingTests",
            dependencies: ["ScreenshotIndexing"],
            path: "Tests/ScreenshotIndexingTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
