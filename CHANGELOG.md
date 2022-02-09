## [1.3.0 - ?? ??, 2022](https://github.com/Figure53/F53OSC/releases/tag/1.3.0)

### F53OSCEncrypt
- Adds the ability to transmit OSC messages using encryption. (NOTE: this is F53OSC-specific, not based on the OSC spec.) The core of the encryption is written in Swift using CryptoKit, including P521 public/private keys, HKDF derived symmetric keys, and ChaChaPoly symmetric encryption.
  - Adds an encryption handshake protocol transmitted over an F53OSC control message channel (starting with `!` instead of `/` to differentiate it from OSC messages). 
  - Adds an encrypted message type, which consists of encrypted OSC message data prefixed by a `#` character.
- Clients wishing to support encryption must first generate a key pair using the `generateKeyPair` method of `F53OSCEncrypt` and then call `connectEncryptedWithKeyPair:` on their `F53OSCClient`.
- Servers wishing to support encryption must first generate a key pair using the `generateKeyPair` method of `F53OSCEncrypt` and then call `setKeyPair:` on their `F53OSCServer`. 
- Additionally, both servers and clients can check the `encrypter.publicKey` property of an `F53OSCSocket` to verify the identity of a peer if they wish to do so.

### More
- F53OSC.xcodeproj is updated for Xcode 13.
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
