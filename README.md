# F53OSC

Hey neat, it's a nice open source OSC library for Objective-C.

From your friends at [Figure 53](https://figure53.com).

For convenience, we've included a few public domain source files from [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).  But appropriate thanks, kudos, and curiosity about that code should be directed to [the source](https://github.com/robbiehanson/CocoaAsyncSocket).

## Usage Notes

- F53OSC must be compiled with ARC.
- You must link against `Security.framework` and `CFNetwork.framework`.
- F53OSC requires Xcode 16.2 or later and a minimum deployment target of macOS 11, iOS 14, or tvOS 14.


## Installation

F53OSC includes support for [CocoaPods](https://cocoapods.org) and [Swift Package Manager](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Usage.md). You can also manually integrate the files in your project.

### CocoaPods

Add the following line to your `Podfile`:

```ruby
pod 'F53OSC', :git => 'https://github.com/Figure53/F53OSC.git'
```

Then run:

```bash
pod install
```

Make sure to open the `.xcworkspace` file rather than the `.xcodeproj` file after installation.

### Swift Package Manager

For Xcode projects, go to **File** > **Add Package Dependencies...**, enter the repository URL `https://github.com/Figure53/F53OSC`, and select the version you want to use.

If you're developing a Swift Package, add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Figure53/F53OSC.git", from: "X.Y.Z") // Replace with desired version
]
```

Then add the library to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["F53OSC"]
    )
]
```


## Demo

F53OSC.xcodeproj includes "F53OSC Monitor", a small demo app that logs OSC messages sent to it on port 9999 and displays some basic stats about incoming traffic.

## Version History

* Full [changelog](https://github.com/Figure53/F53OSC/blob/main/CHANGELOG.md).
