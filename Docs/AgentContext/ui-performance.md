# UI launch and artwork performance

Use when changing launch covers, tab mounting, artwork loading/retention, or
first-frame performance. Root guidance owns product approval constraints.

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

