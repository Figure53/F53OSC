## [1.1.0 - Mar 30, 2020](https://github.com/Figure53/F53OSC/releases/tag/1.1.0)

- Adds support for OSC 1.1 type tags `T`, `F`, `N`, and `I`. [#23](https://github.com/Figure53/F53OSC/issues/18)
- Fixes a bug that prevented OSC range patterns from being handled correctly, e.g. `[A-Z]`.
- Fixes a bug that caused the OSC wildcard `?` to incorrectly match on a two-character string ending in "1".
- Fixes a bug when handing an incoming `F53OSCMessage` that caused incorrect parsing of arguments that follow a "Blob" type argument.
- Updates `F53OSCClient` and `F53OSCMessage` with support for NSSecureCoding.
- Updates CocoaAsyncSocket library files `GCDAsyncSocket.h/m` and `GCDAsyncUdpSocket.h/m` to version [7.6.4](https://github.com/robbiehanson/CocoaAsyncSocket/releases/tag/7.6.4).
- Adds build targets for compiling a standalone `F53OSC.framework` bundle.
- Reorganizes the project structure (with a eye toward adding Swift Package Manager support sometime in the future).
- Requires Xcode 10.3 or later.

## [1.0.6 - Feb 16, 2019](https://github.com/Figure53/F53OSC/releases/tag/1.0.6)

## [1.0.5 - Apr 4, 2018](https://github.com/Figure53/F53OSC/releases/tag/1.0.5)

## [1.0.4 - Jan 3, 2018](https://github.com/Figure53/F53OSC/releases/tag/1.0.4)

## [1.0.3 - Oct 24, 2017](https://github.com/Figure53/F53OSC/releases/tag/1.0.3)

## [1.0.2 - Jun 10, 2017](https://github.com/Figure53/F53OSC/releases/tag/v1.0.2)

## [1.0.1 - Aug 31, 2016](https://github.com/Figure53/F53OSC/releases/tag/v1.0.1)

## [1.0.0 - Aug 19, 2014](https://github.com/Figure53/F53OSC/releases/tag/v1.0.0)

- Starting point for semantic versioning.
- Adds F53OSC.podspec.
