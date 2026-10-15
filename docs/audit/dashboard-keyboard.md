# Dashboard keyboard editing

Sources: Patched `160bd35a685a14b9b7a16429975630dea7ad797e` (focused
delete), `438353c475fd2f664a1a88e2fd877736b0214090` (focused add), and
`998317cb7712a01dfb32b8b29874e7715053d92b` (held keyboard reordering).
The final behavior also includes `caf3a06945aa6f366c306111a265db240e73c85a`:
other delete controls disappear during a hold, boundary arrows do not count
as movement, and pointer flights hide delete controls until landing.

The adaptation keeps the main branch's keyed MotionGrid, packed layout,
pointer drag and flight animations, card shapes, AppGlyphs, and dashboard
settings owner. It does not replace the grid with Patched's slot animation
framework or change list sorting. CommonCard accepts a scoped press override
so the card becomes the editing or add-sheet focus target; nested controls
and corner badges stay out of keyboard traversal in that mode. Normal card
presses, skipTraversal, inert state, and action focus remain unchanged outside
that scope.

In edit mode, Enter, Space, and remote select hold the focused card. Direction
keys swap it with the next card in the packed layout, including mixed spans.
These changes are local previews. A second confirmation saves the order once
after a real movement, or deletes the card if no movement occurred. Tab stays
on the held card. Escape, remote Back, and system Back cancel the preview
first, then exit edit mode, then reach the enclosing route. The existing
BackLayerScope remains the history owner; consuming a held cancellation
reinstalls that same layer. Page deactivation continues to end editing.

Grid foreground painting and hit testing keep the held card above its
neighbors during motion, while MotionGrid resolves that foreground by key
even when removed cards are still fading out. Focus follows the held key,
returns to a surviving card after deletion, and cannot enter outgoing cards
or flight overlays. External key changes cancel an obsolete hold; adding
rolls an active preview back before committing the addition. Add-sheet cards
share the existing pointer add callback and suppress repeated activation
until the closing card is disposed.

Regression coverage is in `test/widgets/super_grid_keyboard_test.dart`,
`test/widgets/card_press_override_test.dart`, `test/widgets/grid_test.dart`,
and `test/views/dashboard/add_widget_test.dart`. Existing SuperGrid pointer,
dashboard keep-alive, card focus, and scaffold back tests remain required.
The parent integration task runs Flutter analysis and tests for this batch;
this document does not claim physical keyboard, TV remote, or Apple/Windows
device validation.
