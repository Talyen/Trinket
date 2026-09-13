# UI launch and artwork performance

Use when changing launch covers, tab mounting, artwork loading/retention, or
first-frame performance. Root guidance owns product approval constraints.

The launch cover intentionally holds for at least two seconds while resources
prepare. `LaunchWarmupView` owns that duration, its native timed progress bar,
and the completion callback used by `PreparedAppRoot`. The bar fills from 0 to
100% over those two seconds; it represents the intentional hold, not artwork
decode counts. Do not reconnect it to `PreparedArtworkCache.progress` or add a
separate dismissal timer. If required resources, cast effects, or applicable root
layouts take longer, keep the cover visible with the bar full until they are ready.
Launch completion is latched so finishing starter selection does not reopen the
cover. Deferred catalog decoding does not gate dismissal. Verify that fast
preparation cannot dismiss early and slow preparation cannot expose unprepared
content. Native encounter covers and Collection launch detail sheets must also
wait for the app root’s `isLaunchPresentationReady` environment value; native
presentations can appear above the launch ZStack. Keep root layout acknowledgement
independent of this presentation gate. When Play launches into Mystery or Shop,
retain the launch underlay beneath that initial encounter until its identity clears
or changes. Readiness still permits the native cover to enter; retaining the
underlay prevents the Play hub flashing before its entrance. Capture that identity
only once so later encounters cannot reopen the launch cover. After readiness,
the retained underlay is decorative, hidden from accessibility, and no longer
carries the loading-state identifier. Collection
launch sheets use normal launch dismissal to expose their intended backdrop.

Artwork on the first paint of a tab, sheet, or push is decoded into
`PreparedArtworkCache` at launch (or the owning surface's `.task`) and **pinned**
so deferred catalog warmup cannot evict it. `Image.preparedAsset` falling through
to `Image(name)` sync-decodes on that frame — that is the hitch path, not a
memory win. Do not convert this to on-demand loading. Transient battle and
Collection pins still release when that lifecycle ends; Collection re-keys its
pin task when shelf combatants change so newly unlocked heroes stay hitch-free.
`PlayEncounterCoversModifier` prepares and retains first-visible Mystery and Shop
artwork before publishing an encounter cover, keeping artwork readiness separate
from encounter creation and gameplay eligibility. A mounted cover refreshes its
pins when offer artwork changes, without replacing the cover or exposing undecoded
offer artwork. Campaign launch pins use the same resolved stages and artwork
selection as the map, including Mystery replacements for exhausted recruits.
Campaign and Labyrinth capture their outgoing map presentation before invoking an
encounter action. Retain it only when Mystery or Shop opens, including resolved
recruit artwork and Labyrinth selection; persistence still commits immediately.
While the encounter prepares or is active, browsing content remains mounted and
visually unchanged but cannot receive input or accessibility interaction. Release
the retained values without animation when the encounter ends, reconciling cleared
nodes and floor advancement before the cover reveals the map. Native encounter
covers leave the underlying tab bar in place and ignore tab selection and back
navigation during encounter presentation; only battle and the post-battle talent
flow hide it. Failed opens and empty shops without a cover do not retain the map.

Collection item inspection prepares and pins detail artwork before presenting its
source-linked sheet. Successful salvage retains only the outgoing item's position
and artwork through the native return and source-anchored dissolve; the saved item
is already removed. The retiring card is noninteractive, and losing the source or
leaving the flow ends its decorative presentation and releases the pins.

Contracts retains the displayed board while replacement artwork prepares. Only
the latest offer snapshot may publish, with actions bound to those same identities.
Outgoing pins survive the board crossfade. Superseded preparation, navigation away,
and failed refreshes must not expose mismatched offers or leak artwork pins.

Memory targets and enforcement: [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) Artwork Budgets.

For players who completed starter selection, the selected tab and every hidden
Collection, Homestead, and Options prewarm surface acknowledge nonzero layout
under the launch cover after resource preparation. New players acknowledge the
starter selection root instead. Task yields and elapsed time are not layout
acknowledgements. When exactly one run is prepared,
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
beneath an otherwise hidden container. Keep opacity at one for the immediate return
from battle; do not unmount the stack or add battle observation to its destinations.
The retained battle overlay root owns stable navigation geometry. Battle visibility
switches immediately without fading its hand; keep the overlay mounted for prewarm
and preserve its navigation inset until hidden.
