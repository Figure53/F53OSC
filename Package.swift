// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "F53OSC",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "F53OSC",
            targets: [
                "F53OSC",
                "F53OSCEncrypt",
            ]
        ),
    ],
    targets: [
        .target(
            name: "F53OSC",
            dependencies: [
                "CocoaAsyncSocket",
                "F53OSCEncrypt",
            ],
            publicHeadersPath: "."
        ),
        .target(
            name: "F53OSCEncrypt"
        ),
        .target(
            name: "CocoaAsyncSocket",
            path: "Sources/Vendor/CocoaAsyncSocket",
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("CFNetwork"),
            ]
        ),
        .testTarget(
            name: "F53OSCTests",
            dependencies: [
                "F53OSC",
            ]
        ),
    ]
)
