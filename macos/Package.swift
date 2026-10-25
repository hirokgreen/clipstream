// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clipstream",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Clipstream",
            targets: ["Clipstream"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Clipstream",
            path: "Sources/Clipstream"
        ),
    ]
)
