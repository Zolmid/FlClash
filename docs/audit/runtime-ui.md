# Runtime memory, goroutines and modal focus

The source is pinned Patched `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`; this follow-up applies application UI additions on top of the first integration checkpoint `88476f4641da39e1dd24c84f065aa06054ab2200`. The original mihomo `8380d0e7462f061a964323e9bf3129a236fcc5d5` and existing protocol/models remain unchanged.

| Exact source | Implemented adaptation |
| --- | --- |
| `5d3ba8b410219666a5871e9bd9a226503431552f` | `GoroutineInfo` uses the existing `getGoroutineCount` through CoreController, main DashboardWidgetMetrics/CommonCard/AppGlyphs and ActivePollingMixin. It is an optional registered DashboardWidget, appended to the enum without changing users' default layouts. There is no inert tap action and no new Core/event/statistics owner. |
| `e16e4c6a3504c976888aefa7c7b53cd55cef0114` | The existing memory detail sheet adds a Go-runtime section using `CoreMemoryInfo` from the existing `getMemory` API. It shows objects, unused and idle heap, stacks, runtime/GC metadata, other memory and returned heap with a standard main DonutChart. The extra read runs only while the detail sheet is present and active. Read failures remain retryable. |
| `f9a47b8a771ea84b9e1411a8a82a58ebb84e8e84` | The returned-heap toggle removes that segment and recomputes Go percentages against `sys - heapReleased`; showing it restores the `sys` denominator. The returned-heap row retains its value/control so it can be restored. The process total, Android in-process attribution, independent iOS NE RSS and footprint remain governed by the existing MemorySnapshot logic and are never recomputed from this Go chart. Zero totals produce finite zero shares. |
| `a84e571099fe1392b55e051ab76d892ff7f9e0a6` | The first checkpoint's app/RSS/iOS footprint work is preserved. Runtime categories and footprint are not added to the process RSS total. iOS Go-runtime reads use the same connected-NE requirement as independent Core memory. |
| `dd1fcfba2091dd8b05853c27362f6ec37f18c111` | PageTraversalPolicy keeps ReadingOrderTraversalPolicy and its existing nearest-sidebar/page escape behavior. For a non-opaque route which requests focus, it applies a temporary stop boundary for directional/Tab/Shift-Tab traversal before considering outer scopes. Edge behavior is restored after each traversal. CommonPopupRoute's `modal:false` uses requestFocus=false and is deliberately excluded; no popup/sheet rewrite or second focus owner is introduced. |

Memory-detail and goroutine polls invalidate their generations when Core state changes; iOS additionally invalidates on tunnel-state changes. Late results from a previous Core/route cannot replace the new session. Paused or inactive pages use the existing polling guard. The goroutine card clears its count when the Core channel disconnects and does not call a disconnected channel; a failed read does not stop later polls. On iOS it displays the active Core: connected VPN reads NE, a stable stopped VPN reads App Core, and pending tunnel transitions pause polling. A tunnel-state change clears the previous count and invalidates late results. NE request failures propagate without falling back to App Core; this card is not an NE-only metric.

Production paths: `lib/views/dashboard/widgets/memory_info.dart`, new `goroutine_info.dart`, `widgets.dart`, `widget_registry.dart`, `lib/enum/enum.dart`, `lib/widgets/focus.dart`. There are no changes to dashboard.dart (the keyboard-grid owner), Core models/API, l10n source strings, native files, runtime process ownership or generated code by this owner. The new enum member and its generated serialization map are included in the coordinated build_runner output.

Focused tests:

- `test/widgets/runtime_memory_test.dart`: returned-heap chart/percentage denominator with unchanged process totals; zero/error recovery; stale Core-session completion.
- `test/widgets/goroutine_info_test.dart`: page/lifecycle cadence, actual controller call with old/new Core sessions and disconnect, retry after failure.
- `test/widgets/overlay_focus_test.dart`: modal popup and side-sheet directional/Tab confinement, return to ordinary sidebar traversal after closing, and the explicit nonmodal exception.

Existing MemorySnapshot arithmetic, memory controls, FAB focus, remote-input and TV-back tests remain in place. Formatting, generation, analysis and Flutter execution are coordinated by root; this document does not count test-file creation as passing tests. No Android/iOS TV remote, physical IME or platform-native UI was exercised in this environment.
