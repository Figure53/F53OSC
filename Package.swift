// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "F53OSC",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14)
    ],
    products: [
        .library(
            name: "F53OSC",
            targets: ["F53OSC", "F53OSCEncrypt"]
        )
    ],
    targets: [
        .target(
            name: "F53OSC",
            dependencies: ["F53OSCEncrypt"],
            path: "Sources",
            exclude: [
                "F53OSC/module.modulemap",
                "F53OSC Monitor"
            ],
            sources: [
                "F53OSC",
                "Vendor/CocoaAsyncSocket"
            ],
            publicHeadersPath: "F53OSC",
            cSettings: [
                .headerSearchPath("Vendor/CocoaAsyncSocket")
            ],
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("CFNetwork")
            ]
        ),
        .target(
            name: "F53OSCEncrypt",
            path: "Sources/F53OSCEncrypt"
        ),
        .testTarget(
            name: "F53OSCTests",
            dependencies: ["F53OSC", "F53OSCEncrypt"]
        )
    ]
)
