## [1.3.1 - September 29, 2025](https://github.com/Figure53/F53OSC/releases/tag/1.3.1)

- Adds support for Swift Package Manager.
- Adds F53OSC.xctestplan and comprehensive test suite.

### F53OSCBrowser
- Properties `domain` and `serviceType` now allow setting an empty string.
- Fixes the getter implementation of read-only property `clientRecords`.
- Fixes `stop` to allow for quicker restarts.

### F53OSCBundle
- Adds `copyWithZone:` for proper subclass conformance to NSCopying, declared in the `F53OSCPacket` superclass.
- Invalid `elements` (i.e. non-`NSData`) are now discarded when setting, rather than when reading `packetData`. This fixes an edge case where the bundle `description` could report elements that would not be included in the `packetData`.

### F53OSCClient
- Adds `hostIsLocal` convenience getter.
- Modernizes `readState` dictionary code.
- Refactors `createSocket`, `connect`, and `connectEncryptedWithKeyPair:` for clarity, with the assumption that `createSocket` will always populate the client `socket` property with a non-nil value.
- Fixes a bug when connecting that prevented sending the `clientDidConnect:` delegate message in cases where an encryption handshake request failed.

### F53OSCEncryptHandshake
- Adds enum value `F53OSCEncryptionHandshakeMessageNone` at raw value `0`. This allows `lastProcessedMessage` to be initialized more accurately as "None", prior to making a handshake request. NOTE: Inserting this enum value at position 0 shifts all previously-existing raw values in `F53OSCEncryptionHandshakeMessage` up by 1.
- Exposes `protocolVersion` to public as a class method.
- Changes all public properties to be read-only.
- Generic `init` is now marked as unavailable in favor of using `+handshakeWithEncrypter:` which ensures an encrypter is provided.
- Fixes a typo in `F53OSCEncryptionHandshakeMessageApprove`.

### F53OSCMessage
- Adds missing `kCFNumberCFIndexType` switch cases.
- Adds #define `F53OSC_EXHAUSTIVE_SWITCH_ENABLED` (enabled by default) for compatibility with the `GCC_WARN_CHECK_SWITCH_STATEMENTS` build setting.
- Number formatting now uses `NSNumberFormatter` rounding mode `NSNumberFormatterRoundHalfUp`.
- Fixes a small regression in `+messageWithString:` related to parsing quotation marks.

### F53OSCSocket
- Adds `hostIsLocal` convenience getter.
- Generic `init` is now marked as unavailable in favor of using init methods that ensure an internal TCP or UDP socket is provided.
- Fixes `keyPair` property nullable annotation.

### More
- Misc code cleanups.
- Removes F53OSC Monitor.xcodeproj in favor of having multiple targets in F53OSC.xcodeproj.
- Light optimizations and cleanups in the F53OSC Monitor app code.
- F53OSC.xcodeproj is updated for Xcode 16.2.

## [1.3.0 - August 30, 2022](https://github.com/Figure53/F53OSC/releases/tag/1.3.0)

### F53OSCEncrypt
- Adds the ability to transmit OSC messages using encryption. (NOTE: this is F53OSC-specific, not based on the OSC spec.) The core of the encryption is written in Swift using CryptoKit, including P521 public/private keys, HKDF derived symmetric keys, and ChaChaPoly symmetric encryption.
  - Adds an encryption handshake protocol transmitted over an F53OSC control message channel (starting with `!` instead of `/` to differentiate it from OSC messages). 
  - Adds an encrypted message type, which consists of encrypted OSC message data prefixed by a `#` character.
- Clients wishing to support encryption must first generate a key pair using the `generateKeyPair` method of `F53OSCEncrypt` and then call `connectEncryptedWithKeyPair:` on their `F53OSCClient`.
- Servers wishing to support encryption must first generate a key pair using the `generateKeyPair` method of `F53OSCEncrypt` and then call `setKeyPair:` on their `F53OSCServer`. 
- Additionally, both servers and clients can check the `encrypter.publicKey` property of an `F53OSCSocket` to verify the identity of a peer if they wish to do so.

### F53OSCServer
- Adds support for optionally enabling IPv6 support for sockets. NOTE: IPv6 support is experimental and is now disabled by default on both of the internal sockets.

### F53OSCClient
- Adds a `tcpTimeout` property to configure an optional timeout for waiting to receive TCP data to read. Any negative value means "no timeout". The default is `-1`.
- Adds an optional delegate method `client:didReadData:` to notify about the progression of how much data has been read for the current incoming message.

### F53OSCMessage
- Fixes `+messageWithString:` to handle quotation mark characters `“` (U+201C) and `”` (U+201D) as plain quotation marks `"` (U+0022) for better compatibility with certain text editors that automatically format with "smart" quotation marks. [#37](https://github.com/Figure53/F53OSC/issues/37)
- Fixes `+messageWithString:` to fail parsing and return `nil` if quoted string arguments are not separated by spaces.

### F53OSCSocket
- Adds a `tcpDataFraming` property to allow optionally disabling SLIP framing when sending non-OSC data over TCP.
- Fixes the inability to send large packets by removing the timeout when writing data.

### More
- F53OSC.xcodeproj is updated for Xcode 13.
- Requires Swift 5.
- Requires minimum deployment target of macOS 11, iOS 14, or tvOS 14.

## [1.2.0 - Jan 13, 2022](https://github.com/Figure53/F53OSC/releases/tag/1.2.0)

- Adds a new class `F53OSCBrowser` to facilitate Bonjour client discovery.
- Adds support for optionally enabling IPv6 support for clients and sockets. NOTE: IPv6 support is experimental and is disabled by default.
- Changes `+[F53OSCServer predicateForAttribute:matchingOSCPattern:]` to return a FALSE predicate when passed a malformed OSC pattern rather than returning `nil`.
- Several changes to protocols and delegates, namely the protocol `F53OSCServer` is removed in favor of a new `F53OSCServerDelegate` protocol.
- Adds tests to validate OSC wildcard patterns and predicates.
- Adds support for testing arbitrary locales with the number formatter used in `+[F53OSCMessage messageWithString:]` via an optional NSUserDefaults key `com.figure53.f53osc.testingLocaleIdentifier`.
- Updates header comments to reflect correct author name.
- F53OSC.xcodeproj is updated for Xcode 12.

## [1.1.0 - Mar 30, 2020](https://github.com/Figure53/F53OSC/releases/tag/1.1.0)

- Adds support for OSC 1.1 type tags `T`, `F`, `N`, and `I`. [#23](https://github.com/Figure53/F53OSC/issues/23)
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
