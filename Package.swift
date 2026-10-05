// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Eyelid",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Eyelid",
            path: "Sources/Eyelid"
        ),
        .testTarget(
            name: "EyelidTests",
            dependencies: ["Eyelid"],
            path: "Tests/EyelidTests"
        ),
    ]
)
