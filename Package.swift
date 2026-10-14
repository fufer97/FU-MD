// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FUMD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FUMD",
            path: "Sources/FUMD",
            resources: [.copy("Resources")]
        )
    ]
)
