# F53OSC Modernization Notes

Companion document to the `nw-modernization` branch. Covers the things callers
need to know that aren't obvious from the diff: feature additions, API contract
changes, and behavior differences from the legacy GCDAsync-backed implementation.

The Network.framework swap itself is documented in the commit message at
`F53/F53OSC@843d4fe`. This file covers everything else.

---

## What changed at a glance

1. **Performance.** SLIP encoder and decoder were rewritten to scan for runs of
   ordinary bytes and emit them in a single `appendBytes:length:` call rather than
   one call per byte. Codec microbenchmark measures 6× encode speedup and 2.3×
   decode speedup on typical OSC messages; no regression on adversarial payloads.
   `F53OSCStats` counters moved from `@synchronized(self)` to C11 `_Atomic(double)`
   with a lock-free CAS update; per-datagram stats updates no longer hold a lock.

2. **Test coverage.** Five new test files (Throughput, Stats, SLIPRoundtrip,
   UDPFlow, UDPClientHostChange) cribbed from F53OSC-Swift's test suite plus a
   codec microbenchmark with paired legacy/vectorized variants to validate the
   perf claims. F53OSC_BrowserTests was rewritten on an internal-seam test
   pattern since the old NSNetServiceBrowser-delegate-poking pattern doesn't
   port. ~32 tests are marked `XCTSkip` with TODOs explaining why
   (see *Test skips* below).

3. **Public API.** A few small additions for parity with F53OSC-Swift; one
   deprecated surface removed outright.

4. **Internal architecture.** F53OSCSocket now keeps two queues — a private
   `_internalQueue` for Network.framework callbacks and a `_callbackQueue` for
   delegate method invocations. Prevents a class of dispatch deadlocks that
   would have surfaced under tests blocking on main while waiting for receives.

---

## API additions

### F53OSCServer

- `udpFlowIdleTimeout` (NSTimeInterval; default 30, 0 disables) — seconds of
  inactivity before an accepted UDP "flow" (one `nw_connection_t` per source
  endpoint) is cancelled and removed.
- `udpFlowSweepInterval` (NSTimeInterval; default 5) — cadence of the sweep
  timer that enforces the idle timeout. Smaller values are useful for tests;
  production default is fine for normal use.

### F53OSCBrowser

- `F53OSCClientRecord.service` (F53OSCServiceRef *) — the new resolved-service
  surface. Carries name, type, domain, host, port, hostAddresses, txtRecord.
- `-browser:shouldAcceptService:` delegate method (F53OSCServiceRef *) — the new
  filter callback. The legacy `shouldAcceptNetService:(NSNetService *)` filter is
  **gone**; see *Removed API* below.

### F53OSCServiceRef (new)

- Immutable value type. Returned from F53OSCBrowser; not constructed by callers.
- `init` is `NS_UNAVAILABLE`; use the designated initializer if you need to
  construct one for tests via the internal seam.

### F53OSCSocket

- `secondsSinceLastActivity` (readonly NSTimeInterval), backed by a lock-free
  atomic CFAbsoluteTime. Returns `-1.0` if no data has arrived yet, so callers
  can distinguish a newborn connection from a stale one. Drives the UDP
  idle-flow sweep, also useful for callers that want to diagnose stuck connections.

### F53OSCParser

- `+slipFrameData:` — class method that frames bytes as a double-END SLIP packet.
  Production code (`F53OSCSocket -sendPacket:`) calls this; benchmarks and
  integration tests also use it directly. The legacy SLIP encoder lived
  inline in `-sendPacket:` and wasn't reusable.

### F53OSCSocket+Internal.h (new internal header)

- `+socketWrappingAcceptedConnection:isTcp:host:port:callbackQueue:` — factory
  used by listeners' new-connection handlers to wrap accepted `nw_connection_t`s
  as child F53OSCSockets.
- `-sendRawBytes:` — test-only entry point that pushes pre-shaped bytes through
  the underlying connection without encryption or SLIP framing. Used by
  encryption-rejection tests that inject mismatched-key payloads. **Production
  code must not call this.**

### F53OSCBrowser+Internal.h (new internal header)

- `-_addDiscoveredService:` / `-_removeDiscoveredService:` — test seam methods.
  Real production discovery comes from `nw_browser_t` callbacks calling into the
  same code path; tests bypass the network and feed synthetic
  `F53OSCServiceRef`s directly.

### F53OSCStats

- `-completeCurrentInterval` — test-only hook that forces the 1-second window
  to rotate synchronously, without waiting for the timer. Matches F53OSC-Swift's
  `OSCStats.completeCurrentInterval()`.

---

## Removed API

### F53OSCBrowser deprecation shim — gone

`F53OSCClientRecord.netService` (the `NSNetService *` property) and
`-browser:shouldAcceptNetService:` (the NSNetService-typed delegate method) are
removed outright on this branch. Both `NSNetService` and `NSNetServiceBrowser`
are deprecated since macOS 12 / iOS 15; keeping a compatibility shim would have
required `#pragma clang diagnostic ignored "-Wdeprecated-declarations"`
suppressions throughout, which defeats the modernization's intent. Callers must
migrate to `F53OSCClientRecord.service` (an `F53OSCServiceRef *`) and
`-browser:shouldAcceptService:`.

### F53OSCSocket — GCDAsync-typed factories and properties gone

The legacy `+socketWithTcpSocket:`, `+socketWithUdpSocket:`, `-initWithTcpSocket:`,
`-initWithUdpSocket:` and the `tcpSocket` / `udpSocket` readonly properties (all
returning `GCDAsyncSocket *` / `GCDAsyncUdpSocket *`) are removed. Use the
role-based factories on F53OSCSocket: `+outboundTcpSocketWithCallbackQueue:`,
`+outboundUdpSocketWithCallbackQueue:`, `+tcpListenerWithCallbackQueue:`,
`+udpListenerWithCallbackQueue:`. The discriminator methods `isTcpSocket` and
`isUdpSocket` are still there.

### F53OSCBrowser+IPAddressFromData: class method — gone

The byte-parsing helper for `NSNetService` address bytes is no longer present.
`nw_browser_t` resolves the endpoint directly so this helper has no home.
Callers shouldn't have been using it (it was effectively private), but a sweep
of dependent projects to confirm is reasonable.

---

## Behavior differences from legacy GCDAsync

These are contract changes that callers will see. They mostly come from
Network.framework's semantics; F53OSC-Swift adopts the same changes.

### `F53OSCSocket.connect` is non-blocking for TCP

Legacy `GCDAsyncSocket connectToHost:onPort:...` returned `YES` to mean "the
syscall to start connecting succeeded" — not "the connection is ready."
The handshake completed asynchronously and `clientDidConnect:` fired afterward.

In the prototype's first iteration, our `connect` blocked synchronously waiting
for `nw_connection_state_ready`. That created dispatch deadlocks whenever the
caller and the connection's callback queue were the same (typically both on
main). Reverted to the legacy non-blocking contract. **Callers that expect
"connect returned YES" to mean "the connection is ready" are wrong on both
the legacy code and the modernized code** — they must wait for
`clientDidConnect:` or poll `isConnected`.

### UDP `isConnected` returns NO by default

Legacy `GCDAsyncUdpSocket.isConnected` returned YES by default for unconnected
UDP sends (UDP is connectionless). The modernized F53OSCSocket tracks an
underlying `nw_connection_t` that isn't started until first send, so
`isConnected` is NO until then.

Affects code that used `isConnected` as a "should I send?" gate on UDP. The
recommended pattern now is to just send; the lazy-connect path is internal.

### Port reuse is enabled on listeners

`nw_parameters_set_reuse_local_address(true)` is set on all listener
parameters. Required for `stopListening` + `startListening` on the same port to
work cleanly (otherwise the kernel holds the port in `TIME_WAIT` after the
first listener cancels, breaking restart).

Side effect: two listeners can bind the same port without an error. Only one
will receive datagrams (or accept connections); the other is silently shadowed.
**Port-in-use detection is no longer reliable** as an integrity check. Don't
rely on `startListening:` returning `NO` to detect that another process holds
the port.

### TCP connect-refusal and DNS-failure detection takes ~2 seconds

Legacy `GCDAsyncSocket` surfaced TCP RST and DNS NXDOMAIN failures almost
immediately. `nw_connection_t` retries internally for approximately 2 seconds
before reporting `.failed`. There's no public API to opt out of this retry.

Affects tests that expected sub-1-second failure callbacks. Two are now
`XCTSkip`'d. In production this matters mostly for "fast fallback" patterns
where you might try a primary server and switch to a secondary on failure —
the failure detection window is longer.

### UDP listener creates one connection per source endpoint

`NWListener` on UDP spawns an `nw_connection_t` for each unique source
address+port tuple. Without garbage collection, these accumulate as senders
open new ephemeral sockets — eventually exhausting file descriptors.

The UDP idle-flow sweep (controlled by `F53OSCServer.udpFlowIdleTimeout` and
`udpFlowSweepInterval`, see *API additions*) cancels flows that have been idle
longer than the threshold. Sweep is on by default; setting timeout to 0
disables it for special cases.

### `F53OSCServer` rebind is more permissive than F53OSC-Swift

F53OSC-Swift's `OSCServer` is single-shot — calling `start()` after `stop()`
throws `OSCError.alreadyStopped`. Our ObjC implementation lets you call
`stopListening` and then `startListening` on the same instance cleanly. QLab's
`F53OSCServer.setPort:` depends on this rebind pattern, so the ObjC contract
is preserved on purpose. Code that targets both implementations should treat
the server as single-shot for portability.

---

## Performance contract

The codec microbenchmark file `F53OSC_CodecBenchmark.m` includes both the
vectorized (production) and legacy byte-at-a-time implementations side-by-side
so the speedup ratio is directly verifiable from XCTest's `measureBlock:`
output.

Numbers on an arm64 test machine (will vary):

| Workload | Vectorized | Legacy | Speedup |
|---|---|---|---|
| Encode ~256 B OSC message | 0.002 s / 10k iters | 0.013 s / 10k iters | 6× |
| Encode 64 KB blob, no specials | 0.049 s / 1k iters | 0.293 s / 1k iters | 6× |
| Encode high-density specials | 0.011 s / 10k iters | 0.016 s / 10k iters | 1.5× |
| Decode ~256 B OSC message | 0.004 s / 10k iters | 0.009 s / 10k iters | 2.3× |
| Decode high-density specials | 0.017 s / 10k iters | 0.019 s / 10k iters | 1.1× |

The "high-density specials" case (payload alternating between SLIP END/ESC
bytes and ordinary bytes) is the worst case for run-scanning — there are no
long runs. The 1.1× near-parity result confirms the vectorization is
asymptotically safe and doesn't introduce overhead on adversarial input.

### UDP receive ceiling on localhost

`F53OSC_PerformanceTests` includes burst-mode UDP tests that intentionally
exceed the kernel UDP receive buffer to characterize the ceiling. Measured
on macOS with default `net.inet.udp.recvspace = 786432`:

| Test | Burst | Delivered (steady state) | What the number reveals |
|---|---|---|---|
| `testMultiSender_UDP_16Producers` | 16 × 1000 × 24 B | **~4099 / 16000** every iteration | Kernel buffer holds ~4099 small datagrams. Each datagram consumes a fixed-size mbuf cluster (~200 B incl. metadata) regardless of payload, so 4099 × 200 ≈ 820 KB ≈ the 768 KB ceiling. |
| `testPayload_UDP_Large` | 5000 × 4 KB | **~190 / 5000** after warm iter | At 4 KB payload + ~100 B mbuf overhead = ~4200 B/datagram, the same 768 KB ceiling holds ~190 datagrams. |

The numbers are deterministic across runs — that's the signal that this is a
hard kernel limit, not random loss. If a future macOS release changes
`net.inet.udp.recvspace` or the per-datagram mbuf overhead, expect these
numbers to shift correspondingly.

Implications for QLab and other F53OSC consumers:

- **Localhost burst UDP delivery is bounded by the kernel, not F53OSC.** Any
  workload that needs guaranteed delivery should use TCP+SLIP.
- **Real shows don't burst this hard.** Typical OSC traffic is sparse cue
  dispatches over a network, not 16-thread localhost bursts. The ceiling is
  documented but not a practical concern.
- **Raising the buffer is possible but requires `sudo sysctl`.** Network.framework
  does not expose `SO_RCVBUF`, so per-process tuning isn't available from F53OSC.
  See *Future: receive buffer configuration* below.

The companion `testMultiSender_UDP_16Producers_ControlledRate` test paces
sends below the ceiling and verifies near-100% delivery — that's the test
to fail-alarm on for actual F53OSC defects.

### Future: receive buffer configuration

Network.framework's `nw_*` API does **not** expose `SO_RCVBUF` directly.
There is no public knob on `nw_parameters_t` or `nw_listener_t` for tuning
the kernel receive socket buffer size. Options if F53OSC ever needs to
expose this (none are small):

1. **Drop to BSD sockets for the UDP receive path** — large architectural
   reversal of the modernization.
2. **Process-wide `sysctl` adjustment** — requires elevated privileges, and
   affects every UDP socket in the process. Probably wrong layer.
3. **Wait for Apple to expose it on `nw_udp_options_t`.** No public ETA.

For now, raising `net.inet.udp.recvspace` system-wide (via
`sudo sysctl -w net.inet.udp.recvspace=4194304`) is the documented workaround
for high-throughput deployments. F53OSC itself stays at Network.framework
defaults.

---

## Test skips

About 32 tests are marked `XCTSkip` with TODO comments. Categories:

- **Test of removed API** (~16) — tests that asserted things specific to
  `GCDAsyncSocketDelegate` / `GCDAsyncUdpSocketDelegate` method stubs that the
  F53OSCSocketDelegate replacement consolidated into 4 callbacks. Recovering
  this coverage means rewriting against the new delegate API; out of scope for
  the prototype.

- **Behavior changes inherent to Network.framework** (8) — port-conflict
  detection, sub-1-second connect-refusal, UDP isConnected default, etc.
  These would fail against F53OSC-Swift identically and document a real
  cross-modernization contract change.

- **Deferred functionality** (2-4) — interface binding by name (currently
  resolved!), raw-bytes injection for encryption-rejection tests
  (currently resolved!). Skipped, then unskipped as those features landed.

The TODO comments on each skip explain the specific reason. None silently
drop coverage; every skipped test points at either a planned-for-second-draft
fix or a documented behavior change.

---

## Landed in the second pass

These four items closed the parity gap with F53OSC-Swift for everything except
configuration knobs QLab doesn't use:

- **SLIP max-frame guard** — 16 MB cap on the SLIP accumulator, reset and
  resume on overflow. Matches F53OSC-Swift's `SLIPDecoder` default. Two tests
  in `F53OSC_SLIPRoundtripTests.m` (`testSlipDecodeRejectsOversizedFrame`,
  `testSlipDecodeRecoversAfterOversizedFrame`) verify the cap and the
  recover-on-next-END behavior.
- **Interface binding by name** — `F53OSCSocket.interface` is honored via a
  one-shot `nw_path_monitor_t` lookup in `lookupInterfaceNamed()`. Loopback
  hosts skip the bind (kernel only routes loopback through `lo0`, so
  requiring any other interface would leave the connection stuck in
  `.waiting(ENETDOWN)`). Unknown interface name produces a hard failure
  (`startListening:` / `connect` return NO with NSError on listener side).
- **`connectTimeout` property** — Configurable per-instance on
  `F53OSCSocket.connectTimeout` (default 30s, 0 disables) and forwarded by
  `F53OSCClient.connectTimeout`. Async watchdog on the internal queue cancels
  the connection if it hasn't reached `.ready` within the timeout; the state
  handler then fires `.cancelled` and delivers a normal disconnect. Matches
  Swift's `OSCClient.Configuration.connectionTimeout`.
- **TCP idle disconnect** — New `F53OSCServer.tcpIdleTimeout` property
  (default 0 = disabled). The existing UDP-flow sweep timer now also walks
  accepted TCP connections and cancels any whose `secondsSinceLastActivity`
  exceeds `tcpIdleTimeout`. Useful for clearing dead clients in QLab's
  long-running state-server use case.

## Remaining gaps (intentionally deferred)

Configuration knobs that exist in F53OSC-Swift but aren't used by QLab and
don't affect correctness:

- **Length-prefix TCP framing.** Swift exposes `.lengthPrefix` as an
  alternative to SLIP. We only support SLIP.
- **TCP keepalive / no-delay / pipeline depth.** Swift's Configuration knobs;
  not used by QLab.
- **Bonjour publish on F53OSCServer.** Swift's `OSCServer` can advertise via
  `BonjourService`; ours can't currently publish.
- **`includePeerToPeer` / AWDL.** Swift exposes a parameter; we don't.
- **`OSCStats` start/stop/reset/snapshot lifecycle.** Swift's Stats has
  richer lifecycle methods; ours is always-on and adequate.

---

## F53ArtNet vendor refresh (caveat)

The QLab side of the modernization deletes F53OSC's vendored CocoaAsyncSocket.
F53ArtNet has its own copy at `F53/F53ArtNet/third_party/CocoaAsyncSocket/`
and is unmodernized — it still uses `GCDAsyncUdpSocket` directly. We refreshed
F53ArtNet's vendored copy with the newer files from F53OSC's deleted vendor
(F53ArtNet's own copy was older and lacked `enableReusePort:error:`, which
F53ArtNet's own code calls).

This is forward-compatible — the newer CocoaAsyncSocket is API-superset of
the older one. But F53ArtNet should be exercised end-to-end (LightCue ArtNet
output to a real fixture or visualizer) before merging to confirm no
behavioral regression.

---

## File-level summary

| Path | Status |
|---|---|
| `Sources/F53OSC/F53OSCSocket.{h,m}` | Rewritten |
| `Sources/F53OSC/F53OSCClient.{h,m}` | Rewritten (public API preserved) |
| `Sources/F53OSC/F53OSCServer.{h,m}` | Rewritten (public API preserved + udpFlowIdleTimeout/SweepInterval) |
| `Sources/F53OSC/F53OSCBrowser.{h,m}` | Rewritten (NSNetService API removed) |
| `Sources/F53OSC/F53OSCServiceRef.{h,m}` | New |
| `Sources/F53OSC/F53OSCSocket+Internal.h` | New |
| `Sources/F53OSC/F53OSCBrowser+Internal.h` | New |
| `Sources/F53OSC/F53OSCParser.m` | SLIP decoder vectorized; `+slipFrameData:` added |
| `Sources/F53OSC/F53OSC.h` | Umbrella updated |
| `Sources/Vendor/CocoaAsyncSocket/` | Deleted |
| `Tests/F53OSCTests/F53OSC_BrowserTests.m` | Rewritten on internal-seam pattern |
| `Tests/F53OSCTests/F53OSC_ThroughputTests.m` | New |
| `Tests/F53OSCTests/F53OSC_StatsTests.m` | New |
| `Tests/F53OSCTests/F53OSC_SLIPRoundtripTests.m` | New |
| `Tests/F53OSCTests/F53OSC_UDPFlowTests.m` | New |
| `Tests/F53OSCTests/F53OSC_UDPClientHostChangeTest.m` | New |
| `Tests/F53OSCTests/F53OSC_CodecBenchmark.m` | New |
| `Package.swift` | CocoaAsyncSocket target removed; F53OSCEncrypt added to test deps; Network framework linked |
