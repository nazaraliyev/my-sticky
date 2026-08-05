// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Nota",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Nota",
            path: "Sources/Nota",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
