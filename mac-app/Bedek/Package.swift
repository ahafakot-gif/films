// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Bedek",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Bedek", path: "Sources/Bedek")
    ]
)
