// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zohar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Zohar", path: "Sources/Zohar")
    ]
)
