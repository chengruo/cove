// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cove",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Cove",
            targets: ["Cove"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Cove",
            path: "Sources/Cove"
        )
    ]
)
