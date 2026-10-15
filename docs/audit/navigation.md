# Responsive navigation integration

The source behavior is Patched commit
`29c34877c42c65738af99c3de4db8a05e7e38026` (`fix(navigation): preserve routes
across responsive layout changes`), compared against the pinned Patched tip
`7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` and merge base `7c61c90`.

Mainline previously replaced a destination's desktop `Navigator` with its plain
root view at mobile width. The root view's global key could preserve its own
state, but the removed navigator disposed pushed routes and their unsaved edits.
The existing root-content resize test did not cover that route lifetime.

Each destination now keeps the same keyed navigator and root page at all widths.
The existing shared home shell and mobile navigation chrome stay outside the page
view. A destination's observer reports whether it has a subroute; on mobile the
shell hides its navigation and removes its bottom inset while the active stack
has one, leaving the route the full content area. The desktop sidebar remains
outside the destination navigator. Mainline's independent destination stacks,
keep-alive policy, tab transitions and navigation library remain in place.
Patched's single shared stack and its pop-to-root behavior when switching tabs
are not imported.

Destination filtering is unchanged: a destination removed from the navigation
list still hands the view to the first available destination, as mainline's
existing test requires. This change preserves a navigator across layout changes
while its destination remains listed; it does not add a cache for removed
destinations or change `keep: false` disposal when switching away.

The single mobile dock or bar preserves its existing element, keyboard focus and
rapid selection during page transitions. Inactive destinations keep their
existing focus exclusion, activity scope and ticker suppression. The page
traversal policy surrounds the destination navigators so it also governs pushed
routes. Home forwards system back with `maybePop`, allowing the active route's
asynchronous unsaved-edit guard to reject or finish the pop.
Chrome metadata reuses the page-builder subtree so switching tabs retains the
existing search-layer owner's cleanup callback.

`test/pages/home_responsive_navigation_test.dart` covers desktop/mobile round
trips with stable navigator, draft controller and focus; a route opened on mobile
and two independent destination stacks; and asynchronous back rejection and
acceptance while resizing. The existing `test/pages/home_test.dart` covers tab
animation, navigation keyboard traversal, inactive-page activity and root-view
resize behavior. The parent task runs both suites against the shared snapshot.

No Android/iOS device, television remote, desktop shell or real keyboard/IME
session was exercised for this change. Widget tests establish route and focus
state behavior within Flutter; they do not establish those device behaviors.
