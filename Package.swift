// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dotenv",
    products: [
        .library(
            name: "dotenv",
            targets: ["dotenv"]
        ),
    ],
    targets: [
        .target(
            name: "dotenv"
        ),
        .testTarget(
            name: "dotenvTests",
            dependencies: ["dotenv"]
        ),
    ]
)
