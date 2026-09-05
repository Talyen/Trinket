# Artwork working-set retention

Removing launch or imminent artwork pins can appear to save memory while moving
decode work back onto the first navigation frame. `NSCache` eviction alone cannot
preserve assets needed for an imminent screen; retained pins prevent deferred
catalog warmup from evicting them before use.

The relevant implementation is
[PreparedArtworkCache.swift](../../../Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift)
and [PreparedArtwork.swift](../../../Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtwork.swift).
When investigating memory, distinguish intentionally retained first-use artwork
from assets whose owning lifecycle has ended.

[AGENTS.md](../../../AGENTS.md) owns approval constraints;
[the performance playbook](../../../Docs/Platform/PerformanceInvestigationPlaybook.md)
owns budgets and evidence. A checker exception is not a substitute for that decision.
