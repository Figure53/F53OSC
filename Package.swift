// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "F53OSC",
    products: [
        .library(
            name: "F53OSC",
            targets: ["F53OSC"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "F53OSC",
            dependencies: [],
            publicHeadersPath: "")
    ]
)
