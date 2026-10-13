// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GreeBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GreeBar", targets: ["GreeBar"]),
        .executable(name: "greectl", targets: ["greectl"]),
    ],
    targets: [
        .target(name: "GreeKit"),
        .executableTarget(name: "GreeBar", dependencies: ["GreeKit"]),
        .executableTarget(name: "greectl", dependencies: ["GreeKit"]),
        .testTarget(name: "GreeKitTests", dependencies: ["GreeKit"]),
    ]
)
