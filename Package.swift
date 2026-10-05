// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Eyelid",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Eyelid",
            path: "Sources/Eyelid",
            linkerSettings: [
                // A __RESTRICT segment makes dyld ignore DYLD_* variables, so no other program can load its
                // code into Eyelid and use its Accessibility access. The hardened runtime alone doesn't stop
                // that for ad hoc signed builds, which releases are.
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__RESTRICT", "-Xlinker", "__restrict", "-Xlinker", "/dev/null"]),
            ]
        ),
        .testTarget(
            name: "EyelidTests",
            dependencies: ["Eyelid"],
            path: "Tests/EyelidTests"
        ),
    ]
)
