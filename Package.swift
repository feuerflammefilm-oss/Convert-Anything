// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ConvertAnything",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ConvertAnything",
            path: "Sources/ConvertAnything"
        )
    ]
)
