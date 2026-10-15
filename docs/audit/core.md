# Core / mihomo integration audit

## Sources and reproducibility

- Main application reference: `f2112fc4ad202bbe597e6728acaef7700eeb58a5` (`origin/main`).
- Preserved iOS integration baseline: `3222b8d609caaf74c28f61712c8d654e4937eed9`.
- Patched application reference: `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` (`refs/remotes/patched-audit/main`).
- Application merge base: `7c61c90ac20493b474d19c75ec96262b478b4b88`.
- The application range contains 281 commits; 47 touch `core/`. All 47 are listed below, including historical changes subsequently superseded inside Patched.
- Main mihomo: `8380d0e7462f061a964323e9bf3129a236fcc5d5`, remote `chen08209/Clash.Meta`, path `core/Clash.Meta`.
- Patched mihomo: `293cd231748a77229ab99625580e35ec362b5fe7`, remote `chenx-dust/mihomo`, path `core/mihomo`.
- Real mihomo merge base: `88dcbf7f1614a67c3b36b848ee3592dfa92ada36`.
- Main-only mihomo commits: 2; Patched-only: 28. Comparing the two heads changes 84 paths, 2,532 additions and 518 deletions. The original application merge base used mihomo `70f0570405c3c2c47bb113b88db95006d239b346`; it is not the correct base for comparing the current fork heads.
- Both object histories were fetched from the local checkouts into `/tmp/flclash-core-audit.git`. Neither original submodule's remote, HEAD, refs, nor working files were changed to perform the comparison.

Reproduce with `git merge-base mainline patched`, `git rev-list --left-right --count mainline...patched`, and `git diff mainline patched` after importing the exact object IDs above into a disposable bare repository.

## Decisions and current implementation

The final product deliberately keeps `core/Clash.Meta` at **`8380d0e7462f061a964323e9bf3129a236fcc5d5`** and its original upstream URL. No Patched fork or new mihomo feature commit is a product dependency. This is the user's maintenance-cost decision: reusable application wrappers are integrated, while features needing a maintained core fork are deferred. The original sing-tun and sing-wireguard locks are unchanged; the candidate dependency upgrade was reverted with the fork features.

| Capability / source | Final disposition and evidence |
| --- | --- |
| iOS C ABI, NetworkExtension, TUN descriptor ownership (`e6d0712e`, `b3f27cb8`) | Retained from baseline `2c8c9f8f`. Cgo stays in `core/ios/`; the shared package remains pure Go and Android keeps gomobile. The bridge retains/releases Objective-C callbacks and duplicates the NE-owned descriptor. |
| Process caches and provider ownership | Retained iOS integration is stronger than Patched: `.ios-cache/{app,ne}/cache.db` is opened before restoring shared resource home, and App HTTP providers use `.ios-app/` writable copies. `mobile_storage_test.go` opens simultaneous real bbolt databases and verifies actual provider `Initial`/`SideUpdate` isolation. |
| Runtime rules / disable (`2502ef35`) | Migrated `getRules` and `setRuleDisabled` use the original core's `constant.RuleWrapper` with atomic hit/miss counts. Under `configMu`, reads return a rules snapshot with a fresh random token per configuration; writes require that original token plus matching index/type/payload. Applying a configuration, including the default fallback after a parse error, or observing a replaced rules list renews the token. Random tokens also reject stale requests across independent iOS App/NE Core instances. Accepted switches retain their token and advance the existing route epoch. The UI invalidates queued edits and late reads/writes across configuration and tunnel routing changes, and does not query or mutate during pending tunnel transitions or configuration apply. No new rule engine/API or fork change in the submodule is needed. |
| Manual DNS (`03d79e3d`) | Migrated `queryDns` uses the actual default resolver, timeout, existing DNS trace hook, manual initiator, upstream and cache attribution. Tests use a real mihomo Resolver and in-memory DNS client; event queues are preserved. |
| DNS event records (`706dfbe7`) | Main equivalent exists in `dns_query.go`, `hooks.go`, core `dns/patch.go` and `component/resolver/patch.go`; existing typed RR flattening is retained. |
| Core version (`7ea4597c`) | Migrated `getCoreVersion` returns `constant.Version`, supplied by existing build tooling. |
| Detailed memory (`0dff1719`, `e16e4c6a`, `a84e5710`) | Additive `getMemoryStats` fields plus `getMemory` compatibility alias and `getGoroutineCount`. Existing RSS/heap/stack fields stay. iOS bridge reads Mach `phys_footprint`; tests prove the detailed Go categories sum to `Sys`. Footprint is not added to that total. |
| AGE tools | Migrated `generateAgeKeyPair` and `convertAgeSecretKeyToPublicKey` through the existing core AGE library. Tests generate keys, derive the public key and encrypt/decrypt real profile bytes. |
| Proxy details (`588610ef`) | Original core already exposes runtime `ProxyInfo`, `SupportUDP` and `SupportUOT`. The slim non-group node view now carries UDP/UOT/XUDP/TFO/MPTCP/SMUX, provider, dialer proxy, interface and routing mark directly. No node `MarshalJSON`, delay history or duplicate JSON encoding is introduced; a test makes adapter encoding panic while verifying all fields. |
| Precise connection closing (`e36bbc9f`, `eddc23ee`) | `changeProxy` optionally closes only trackers whose recorded group selected a different child. It runs under existing `selectMu`, preserves the `Changed` response, and supports reselecting the current child to clear stale connections. Tests use actual original-core TCP trackers and keep current/unrelated connections. |
| mipstack/default congestion (`78262b27`, `32ca96eb`, `68ae2298`) | Existing main core already supports `constant.TunMips`, mipstack and congestion-controller parsing. No old chenx-dust sing-tun replacement is copied. |
| recvmsg_x / sendmsg_x (`7526372c`, `c6916165`) | Existing original core parses/applies Darwin fields. Runtime `tunSchema` now carries both optional flags, including explicit false; the shared pure-Go mobile decoder accepts Android hyphen keys and iOS camel keys. `SendMsgX=false` default stays because main recorded a Darwin freeze workaround. |
| ICMP / NAT (`42b098b3`) | ICMP remains the existing per-profile override, with Android mobile options forwarding it. No duplicate global owner is added. `endpoint-independent-nat` is not read by the retained sing-tun implementation, so no new setting is exposed or claimed effective; the baseline iOS wire field remains for ABI compatibility. |
| NTP system clock (`1ea84039`) | Main wrapper already disables system-clock writes on Android and iOS before apply. Resolver/time synchronization remains enabled. |
| Provider suspend / Doze (`34d6ffc0`, `f713793a`) | Keep main lifecycle ownership and no-suspend policy. Patched later reverted its health-check pause (`32de615f`); the historical pause is not reintroduced. |
| Existing low-memory behavior | Keep main's provider-completion memory release and `ForceGC` proxy-cache invalidation, existing `with_low_memory` pool sizes, and iOS NE Go memory limit. These are useful existing controls, not equivalents to the deferred AnyTLS/mmap/concurrency features. |
| Managed data hardening (`46ada1e8`) | Adapted to the scoped `clearEffect(profileId)` API. `os.OpenRoot`, `Lstat`/`SameFile` checks reject symlinked `.ios-app`, `profiles` and `providers` scopes; only the numeric profile entry is removed in each owned store. Tests keep other profiles and outside directories. No arbitrary delete-path API is introduced. |
| Bounded log/request replay (`e36bbc9f`) | Keep main's three event queues and existing native NE backlog rather than duplicate Patched's 100-entry Go histories. NE attaches its queue before QuickSetup; `ios/Shared/CoreEventBacklog.swift` bounds transient data to ten files/512 KiB each and typed state to 256 keys/4 MiB. This provides NE diagnostics/late attachment without another retained in-core replay cache. |
| Generic Cgo Android / desktop | Rejected. Main keeps pure-Go core, gomobile callbacks, current JSON envelopes, bounded queues and framed desktop IPC. |
| Whole-fork replacement | Rejected. It would discard main's TLS certificate hooks, proxydialer cycle protection, direct-type accounting and group `use-position`; both main-only commits remain reachable unchanged. |

### Deferred features requiring a core fork

These features are **absent from the product API and UI**, not simulated from incomplete data:

- Advanced `queryRule` (`41d99c92`, core `2340bf63`): the real engine's `resolveMetadata` is private. A duplicate wrapper would diverge for PASS/rematch/subrules, process matching, DNS and mode handling. The saved extension forwards to the actual engine without an outer recursive `configMux.RLock`.
- Real per-node cumulative traffic (`531a59a3`, `dc107c90`, core `dc915826`, `ada63dbd`): polling live trackers cannot preserve closed-connection bytes. Outbound-owned counters and TCP/UDP fast-path integration require a core extension; existing aggregate traffic remains.
- Overlay details/activation/Tailscale ping/logout (`f2acf0d0`, `01c782bd`, core `aaf192f1`, `c17805d6`, `2e4d36a9`): original outbound implementations hide the required handles. Existing core overlay transport support is retained, without invented status or reflection.
- TUN system DNS mode (`da3a9e57`, core `3893e609`): original RawTun/LC.Tun and locked sing-tun lack the implementation. DNSMode schema/UI is removed rather than silently ignored.
- iOS system-stack forwarder binding (`5f6e0fb0`, core `abc3e3cf`): requires an original-core `forwarderBindInterface` change. Current iOS stack limitations remain; no claim of full system-stack parity is made.
- Low-memory provider concurrency (`4d8eb310`): the saved feature extends the original cap of five to `with_low_memory`; it is not serial loading. Current product retains the original build constraints.
- Android loopback detector (`34842c29`, core `293cd231`): original core forcibly disables that detector on Android. Changing this requires maintaining core code; product leaves it unchanged and retains the separate main proxydialer cycle guard. iOS already uses the detector.
- AnyTLS low-memory idle budget (`4157e6b3`, `34b8fe2c`, core `8a69180c`, `2fea908d`): complete global 16-slot insertion/reuse/expiration/close accounting was saved, including ordinary-build gating. No isolated fix or incomplete budget enters the product.
- Memory-mapped geodata (`74cf3f4b`, core `5bd46cc1`, `db75fb73`): real v2 binary format, mapped domain/IP sets, owner lifetimes, invalidation and atomic publication require core changes. The saved implementation adds rooted path validation and documents the little-endian format. It cannot be replaced by GC or an inactive wrapper flag.

### Preserved work, outside product dependencies

Unfinished fork work was saved in local branch `codex/mihomo-integration`, commit **`199f4e6d30f5603bc1cc9cd658b16b00fd2557f5`**, then the product submodule was restored to a clean detached checkout at `8380d0e7`. Nothing was pushed and `.gitmodules` was not changed.

`/workspace/patched-core-deferred/README.md` records exact base/head and checksums. That directory holds a verified full-history Git bundle, `git diff --binary` patch, full wrapper Go source snapshot (including untracked tests), and tracked wrapper diff before reduction. It is intentionally outside the application repository. The preserved mmap work requires Go 1.25 (`os.Root.Rename`) and declares `go 1.25.0`; the retained product submodule's original `go 1.20` declaration stays unchanged and the application continues using Go 1.27.1. The WIP snapshot must undergo fresh validation if integration is resumed.

## Application commits touching core (complete range)

- `46ada1e8a9bfd743743554a18c3e0ce4102b01e4` — fix(core): harden runtime and managed data handling
- `43964ff168f66bbc315fab0be22a384e89397902` — feat(config): extend profile and network support
- `4d3ce623c86a2ff84046597c21961d0cee492e5d` — feat(android): improve platform integration
- `e6d0712eefb54ed32e03a335a5ae9d6da0a527c4` — feat(ios): add platform support
- `5d3ba8b410219666a5871e9bd9a226503431552f` — feat(dashboard): expand runtime and network visibility
- `e36bbc9ff6ce590581cb81355011c85e85a91e73` — feat(connection): improve logs and connection management
- `b3f27cb80aa4e23b3f30d6a34c042d2362aa3458` — refactor(core): align mobile build constraints
- `34d6ffc052359c6b48cf712d0bbaf5f7f3f4a240` — fix(core): pause provider health checks while suspended
- `c691616521dea9243ee6be5c193ab2ef63a6221a` — fix(ios): disable msgx to decrease memory usage
- `0dff1719f502be7cc30f6a001775a0fa4d2a97a6` — chore(core): improve memory statistics
- `7dbd1142e2915237c7c0703e87392ca18284229f` — fix(core): limit single core and fix bug for lower memory consumption with go mod tidy
- `ffc853869b79fa18f2d7f4cb86be6e6286d69c45` — fix(build): reconcile release notes and iOS exit handling
- `2158e60181cb12e72c1c9a867cce95a0e4ee33c5` — chore: bump version and tune go mod
- `78262b27c4ffd085f96d499390d45d5fe9b1a4d6` — feat(core): update mihomo and add mipstack support
- `f2acf0d0850d59298015a928e5a6623d5e0b6e35` — feat(networking): add EasyTier network and peer details
- `32ca96eb5c8af04108b5dc73fd264d5cce785695` — feat(network): default to mipstack and restore iOS TUN stack selection
- `7526372c6a68696dac4927a6ee6ac1d220a5a26e` — feat(network): add recvmsg_x and sendmsg_x toggles on macOS and iOS
- `74cf3f4b185a62fc7fc247553c2beaee662ffa95` — perf(core): use memory-mapped geodata matcher caches
- `5f6e0fb022bd5646c19b51e9afc3ae0b5406074c` — fix(ios): system stack support
- `4157e6b34a3a461a14df6cb18ae1e4467e1e0ccc` — perf(core): reduce retained memory in low-memory builds
- `ec4e7f3b97795ffaae456f54fb0a45da82573650` — chore: bump version
- `34b8fe2cf0138c45f1cc215d31e2f76306970401` — fix(core): update mihomo to fix anytls connection release
- `7839111f328eef5c01a3c75a14929d2720ed7af1` — chore(core): sync mihomo to ceb217c58
- `33bf9b6cb15f7fb61aef3eaa3e031bdf00dc3a4f` — build(core): update mihomo and Go dependencies
- `1ea840396a61c8eb20feaa140a4fe0ae9b93448c` — fix(core): keep NTP from setting the system clock on Android and iOS
- `9dab0426107bfc65a07adf4e6a27fcce8533631c` — chore(core): update mihomo to mieru 3.38.0
- `706dfbe76c5b467555227bb20e4936b20abe88f4` — feat(dns): show recent core DNS queries
- `01c782bd8af43fb1133d7f3bec90efcff938f61c` — feat(networking): show EasyTier flags and fold local nodes into the list
- `68ae229833b42b63d67bcb109e087d16d791bdc1` — feat(tun): choose the mips congestion controller
- `f713793ae8bed112a8b30a084940beb31cb71ed8` — fix(core,android,ios): stop suspending the tunnel while the device sleeps
- `42b098b39c678b6b9f6e01ab2dae59566edcba9e` — fix(config): apply all TUN settings and controller secret updates
- `ccb77409df6ebef70ebabdf382d8d74cf135dd21` — chore: bump mihomo version to v1.9.32
- `19c5cb50cdd8289962a3a7b327f9e97bff0d09ee` — fix: keep empty Android DNS reports from blocking the system resolver
- `e16e4c6a3504c976888aefa7c7b53cd55cef0114` — feat(dashboard): add detailed memory usage controls
- `65c15c871636dd78544cc33ab85e9f375c587a3f` — chore(deps): upgrade Flutter, Rust, and Android dependencies
- `531a59a3d6264d83415475f40289626d752693d8` — feat(dashboard): show per-node traffic breakdown
- `dc107c90b0bbfc95f1a8ca4a59ab2c1292d09a1c` — feat(dashboard): show direct traffic in node statistics
- `f240b994ad9cfafdb4dcbb661b4a649681d93708` — fix(dashboard): stabilize traffic chart transitions and legend layout
- `52e8c47a56dd0e2654c0ecd051e67fc1d1af55bb` — build(core): use the chenx-dust sing-tun fork
- `03d79e3dc8357bcc27242950ea1bfbec5fb2808e` — feat(dns): query DNS manually from the DNS queries page
- `2502ef3569c2703d52899db59444f902363d162a` — feat(ui): add runtime rules panel and shared proxy chains
- `41d99c9201d256bdbb525d005da793c0f160bedc` — feat(rules): add interactive rule queries with advanced metadata
- `34842c290505db92cd06eed7e1a007822d63b9fc` — fix(core): enable loopback detection on mobile
- `da3a9e57878bfda7dc85fdec463e87964c7b62c4` — feat(tun): add system DNS mode selection and update mihomo
- `1cad08ba10c99959b835cdf1286453232d1e4e53` — fix(android): derive the run state from the service that actually runs
- `a84e571099fe1392b55e051ab76d892ff7f9e0a6` — feat(dashboard): show app memory and iOS memory footprint in memory details
- `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` — feat(about): show the bundled mihomo version

## Patched-only mihomo commits (complete range)

- `9f053c49075de076d83d3e5918241e410f7e9adf` — chore: lazy init wireguard device and stack
- `1354e52e6f72b94c1e684788f1a9c3e0a731e544` — fix: unpassed loadbalance test
- `80101933c007185c7a72efb3a377482b2bb70246` — fix: bound doh dials so ones the query gave up on cannot pile up (#3274)
- `e4dd968de9e10ecc6770acfafd306edeb578eb52` — fix: keep fake-ip allocation state when cloning the pool on reload (#3283)
- `3893e609b7772e552e47dcbbbbfa91d59a92956d` — feat: support dns mode
- `d02880bbac75ef281e70e408f1a1432a310709d9` — feat: support FlClash
- `69134d2623a1d2d51778880c79ce324d7c7d3175` — chore: make alert from server a warning instead of error
- `4d8eb31063c6ce1d0b0c9cc69299926233b220a8` — feat: support ios lowmem
- `5bd46cc13b8312ce50d1f76368865217c44f9fbd` — feat: matcher cache
- `64cd08e83ed466e16b1862682e9dbbd6918a6cbd` — feat: expose ruleset format
- `bf313a6c342461fe84cfb96c2efe2fccba5be179` — fix: ios path and detector
- `aaf192f14ce1286690e253666ffba87db15c2f90` — feat: expose tailscale and zerotier interface
- `5720e2f39bd9f441f9e5257f4c6ea24715812997` — refactor: clean up mobile build patches
- `6cefca9d1f7693f60a7f9fa81bbad729e2dd05f2` — fix(provider): pause health checks while suspended
- `c17805d6327ed99f163340cf3597d9fda14318b7` — feat: support report easytier status
- `db75fb73e3c9318eb252cbfa954bafb0a956e08c` — perf(geodata): load v2 matcher caches through memory mapping
- `abc3e3cff63be11c524559a7bed024e3741ffd8d` — fix(ios): system stack support
- `f0acca1f1d2bd9988596ce160e26a71f06d28f61` — revert: remove unnecessary lowmem process
- `8a69180cd680630558e4be2e50e9c762611dc191` — fix: limit idle connections of anytls in lowmem
- `2fea908d1f714e91c161c0c875e28e8315bc9f85` — fix(anytls): bug cannot release connection without lowmem
- `076b97b2862cdde82406052d8321693d3739e6c9` — fix(ntp): skip settimeofday on Android and iOS
- `f4c336724f7890f5f5974fc06ec3c9e575cfe5cf` — feat: trace DNS queries with initiator and upstream
- `2e4d36a9233ec7c53eb03bd69b9b499d69772426` — feat: report EasyTier peer feature flags
- `32de615f95e558609d08e9de8937f755be66b9bf` — fix: drop the health-check pause added for core suspend
- `dc915826227ee1477d183af06cab8d398037cd9e` — feat: track traffic with outbound-owned counters
- `ada63dbd11ed00fb3063b75fa470df5edba0226c` — feat(statistic): include direct connections in node traffic
- `2340bf63ab49a06b7486e75a449ddfd60e940a95` — feat(tunnel): expose metadata resolution for rule queries
- `293cd231748a77229ab99625580e35ec362b5fe7` — chore: always detect loopback

## Complete mihomo file delta between current heads

```text
M	adapter/adapter.go
M	adapter/outbound/base.go
M	adapter/outbound/easytier.go
A	adapter/outbound/easytier_status.go
A	adapter/outbound/easytier_status_stub_test.go
A	adapter/outbound/easytier_status_test.go
A	adapter/outbound/easytier_status_types.go
M	adapter/outbound/easytier_stub.go
M	adapter/outbound/tailscale.go
M	adapter/outbound/tailscale_stub.go
M	adapter/outbound/wireguard.go
A	adapter/outbound/zerotier_status.go
A	adapter/outbound/zerotier_status_test.go
A	adapter/outbound/zerotier_status_types.go
M	adapter/outbound/zerotier_stub.go
M	adapter/outboundgroup/fallback.go
M	adapter/outboundgroup/groupbase.go
M	adapter/outboundgroup/loadbalance.go
M	adapter/outboundgroup/loadbalance_test.go
M	adapter/outboundgroup/parser.go
D	adapter/outboundgroup/patch.go
D	adapter/outboundgroup/patch_test.go
M	adapter/outboundgroup/selector.go
M	adapter/outboundgroup/urltest.go
M	adapter/patch.go
A	common/mmap/file.go
A	common/mmap/file_stub.go
A	common/mmap/file_unix.go
A	common/mmap/file_windows.go
A	component/cidr/ipcidr_set_mapped.go
M	component/fakeip/pool.go
M	component/fakeip/pool_test.go
M	component/geodata/init.go
A	component/geodata/matcher_cache.go
A	component/geodata/matcher_cache_test.go
A	component/geodata/router/condition_bin.go
A	component/geodata/router/condition_bin_test.go
A	component/geodata/router/matcher_format.md
M	component/geodata/utils.go
M	component/http/http.go
D	component/http/patch.go
M	component/loopback/detector.go
M	component/proxydialer/byname.go
D	component/proxydialer/patch.go
D	component/proxydialer/patch_test.go
A	component/trie/domain_set_mapped.go
A	component/trie/domain_set_mapped_test.go
M	config/config.go
M	constant/adapters.go
A	constant/features/ios.go
A	constant/features/ios_stub.go
M	constant/matcher.go
M	constant/path.go
A	constant/traffic.go
M	dns/doh.go
M	docs/config.yaml
M	go.mod
M	go.sum
M	hub/executor/concurrent_load_limit.go
M	hub/executor/concurrent_load_unlimit.go
M	hub/executor/executor.go
M	hub/route/configs.go
D	hub/route/patch_android.go
A	hub/route/patch_mobile.go
M	listener/config/tun.go
D	listener/http/patch_android.go
M	listener/inbound/tun.go
M	listener/sing_tun/server.go
D	listener/sing_tun/server_android.go
M	ntp/ntp/time_stub.go
M	ntp/ntp/time_unix.go
D	rules/provider/patch_android.go
M	rules/provider/provider.go
M	transport/anytls/session/client.go
M	transport/anytls/session/session.go
M	tunnel/dns_dialer.go
A	tunnel/node_traffic.go
M	tunnel/patch.go
M	tunnel/statistic/manager.go
A	tunnel/statistic/node.go
M	tunnel/statistic/patch.go
D	tunnel/statistic/patch_android.go
M	tunnel/statistic/tracker.go
M	tunnel/tunnel.go
```

## Verification

- The post-review runtime-rules tests pass with `CGO_ENABLED=0 go test . -run 'Test(NewCoreRules|SetRuleDisabled|RuleMutation)' -count=1` and `CGO_ENABLED=0 go test -tags=with_low_memory . -run 'Test(NewCoreRules|SetRuleDisabled|RuleMutation)' -count=1`. They cover same-generation switches, identical DOMAIN/MATCH rules replaced by another configuration, and tokens from an independent Core instance. The corresponding Dart controller/protocol/runtime-rules tests pass in the root's targeted 206-test run.
- On the retained `8380d0e7` core and original dependency locks, `CGO_ENABLED=0 go test -p=4 . ./cmd/... ./tun` and `CGO_ENABLED=0 go vet -p=4 . ./cmd/... ./tun` pass.
- `CGO_ENABLED=0 go test -p=4 -tags=with_low_memory . ./tun` passes.
- Android arm64 portable checks: `GOOS=android GOARCH=arm64 CGO_ENABLED=0 go vet -p=4 -tags=with_gvisor . ./mobile ./tun ./platform` passes.
- Darwin arm64 portable checks with `-tags=ios,with_gvisor` and `-tags=ios,with_gvisor,with_low_memory` pass for `. ./tun ./platform`.
- A Darwin build-tag check covers Go API compatibility, not iOS linking. Linux has no Apple SDK; Mach/NetworkExtension runtime, static archive linking and device tunnel behavior still require Xcode/device verification.
