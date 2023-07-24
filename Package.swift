// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Theo",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        .library(name: "Theo", targets: ["Theo"])
    ],
    dependencies: [
        .package(
            name: "Bolt",
            url: "https://github.com/lewisgodowski/Bolt-swift.git",
            branch: "develop/async-await"
        )
    ],
    targets: [
        .target(
            name: "Theo",
            dependencies: ["Bolt"]),
        .testTarget(
            name: "TheoTests",
            dependencies: ["Theo"])
    ]
)
