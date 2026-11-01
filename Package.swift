// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NativeBrightness",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NativeBrightness", targets: ["NativeBrightness"])
    ],
    targets: [
        .executableTarget(name: "NativeBrightness"),
        .testTarget(name: "NativeBrightnessTests", dependencies: ["NativeBrightness"])
    ]
)
