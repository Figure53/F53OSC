# F53OSC

Hey neat, it's a nice open source OSC library for Objective-C.

From your friends at [Figure 53](http://figure53.com).

For convenience, we've included a few public domain source files from [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).  But appropriate thanks, kudos, and curiosity about that code should be directed to [the source](https://github.com/robbiehanson/CocoaAsyncSocket).

## Usage Notes

- GCDAsyncSocket.m and GCDAsyncUDPSocket.m both require ARC
- All other files are not ARC-compatible
- You need to link against Security.framework and CFNetwork.framework
