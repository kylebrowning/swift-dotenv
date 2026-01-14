// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-dotenv",
    products: [
        .library(
            name: "SwiftDotEnv",
            targets: ["SwiftDotEnv"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftDotEnv"
        ),
        .testTarget(
            name: "SwiftDotEnvTests",
            dependencies: ["SwiftDotEnv"]
        ),
    ]
)
