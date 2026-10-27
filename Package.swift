// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Piko",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PikoCore", targets: ["PikoCore"])
    ],
    targets: [
        .target(name: "PikoCore", path: ".")
    ]
)
