// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dotenv",
    products: [
        .library(
            name: "Dotenv",
            targets: ["Dotenv"]
        ),
    ],
    targets: [
        .target(
            name: "Dotenv"
        ),
        .testTarget(
            name: "DotenvTests",
            dependencies: ["Dotenv"]
        ),
    ]
)
