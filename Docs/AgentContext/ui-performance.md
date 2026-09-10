# UI launch and artwork performance

Use when changing launch covers, tab mounting, artwork loading/retention, or
first-frame performance. Root guidance owns product approval constraints.

The launch cover intentionally holds for at least two seconds while resources
prepare. `LaunchWarmupView` owns that duration, its native timed progress bar,
and the completion callback used by `PreparedAppRoot`. The bar fills from 0 to
100% over those two seconds; it represents the intentional hold, not artwork
decode counts. Do not reconnect it to `PreparedArtworkCache.progress` or add a
separate dismissal timer. If required resources or cast effects take longer,
keep the cover visible with the bar full until they are ready. Deferred catalog
decoding does not gate dismissal. Verify that fast preparation cannot dismiss
early and slow preparation cannot expose unprepared content.

Artwork on the first paint of a tab, sheet, or push is decoded into
`PreparedArtworkCache` at launch (or the owning surface's `.task`) and **pinned**
so deferred catalog warmup cannot evict it. `Image.preparedAsset` falling through
to `Image(name)` sync-decodes on that frame — that is the hitch path, not a
memory win. Do not convert this to on-demand loading. Transient battle and
Collection pins still release when that lifecycle ends; Collection re-keys its
pin task when shelf combatants change so newly unlocked heroes stay hitch-free.
Memory targets and enforcement: [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) Artwork Budgets.

The four tab roots first-layout under the launch cover, including the tab that
is already selected. Play uses the longer first-layout budget for the hidden
battlefield; other tabs use a shorter budget. When exactly one run is prepared,
Play first-layouts a paused `BattleView` in the overlay at opacity 0. Keep
`TabView` mounted during battle and hide the tab bar; tearing it down
recolds Collection, Homestead, and Options. Do not lazy-build detail bodies
to win a presentation frame — that moves the hitch onto scrolling. Do not
drop the prepared overlay mount; pause its TimelineViews until
`lifecyclePhase` is `.active` instead. Do not push campaign (or other
navigation destinations) under the cover — those views are destroyed on pop,
and a leftover path lands the player off the mode hub.


While the retained battle overlay is active, `PlayBrowsingStack` removes its root
and destination content from touch and accessibility exposure with the shared
visibility modifier. Apply the modifier to the hosted screen content, not just the
outer `NavigationStack`: native navigation hosting can retain accessible children
beneath an otherwise hidden container. Keep opacity at one for the battle crossfade
backdrop; do not unmount the stack or add battle observation to its destinations.
