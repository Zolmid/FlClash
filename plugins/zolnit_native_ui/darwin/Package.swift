// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ZolnitNativeUiCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "ZolnitNativeUiCore", targets: ["ZolnitNativeUiCore"]),
    ],
    targets: [
        .target(
            name: "ZolnitNativeUiCore",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "ZolnitNativeUiCoreTests", dependencies: ["ZolnitNativeUiCore"]),
    ]
)
