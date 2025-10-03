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
                "F53OSC/F53OSCEncrypt.swift",
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
            path: "Sources/F53OSC",
            exclude: [
                "F53OSC.h",
                "F53OSCBrowser.h", "F53OSCBrowser.m",
                "F53OSCBundle.h", "F53OSCBundle.m", 
                "F53OSCClient.h", "F53OSCClient.m",
                "F53OSCEncryptHandshake.h", "F53OSCEncryptHandshake.m",
                "F53OSCFoundationAdditions.h",
                "F53OSCMessage.h", "F53OSCMessage.m",
                "F53OSCPacket.h", "F53OSCPacket.m",
                "F53OSCParser.h", "F53OSCParser.m",
                "F53OSCServer.h", "F53OSCServer.m",
                "F53OSCSocket.h", "F53OSCSocket.m",
                "F53OSCTimeTag.h", "F53OSCTimeTag.m",
                "F53OSCValue.h", "F53OSCValue.m",
                "NSData+F53OSCBlob.h", "NSData+F53OSCBlob.m",
                "NSDate+F53OSCTimeTag.h", "NSDate+F53OSCTimeTag.m",
                "NSNumber+F53OSCNumber.h", "NSNumber+F53OSCNumber.m",
                "NSString+F53OSCString.h", "NSString+F53OSCString.m",
                "module.modulemap",
            ],
            sources: ["F53OSCEncrypt.swift"]
        ),
        .testTarget(
            name: "F53OSCTests",
            dependencies: ["F53OSC", "F53OSCEncrypt"]
        )
    ]
)
