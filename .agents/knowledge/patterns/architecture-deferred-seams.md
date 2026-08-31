# Deferred architecture seams

Status: active. Confidence: medium.

Keep these seams deferred until a concrete forcing function appears. The current
boundaries are intentional and should not be split for predicted future reuse.

| Seam | Current decision | Revisit when |
|---|---|---|
| `TrinketContent` catalogs vs procedural systems | Keep one package while the catalog and procedural consumers share ownership. | A third independent consumer or a measured build/ownership problem requires a seam. |
| `TrinketFeatureSupport` by product domain | Keep the shared UI layer while its domains have no independent consumer. | A domain folder gains an independent consumer or ownership boundary that the current package cannot express cleanly. |
| CloudKit enablement | Keep progression local-only. | Developer Program enrollment, portal provisioning, and every item in `CloudKitPreShipChecklist.md` are complete. |
| Further Battle presentation splitting | Keep simulation, projection, feedback, and spectacle as the current owners. | A trace-backed performance or ownership problem demonstrates that an existing owner cannot remain cohesive. |

When a forcing function appears, update this pattern and the owning architecture
documentation together, then remove the replaced boundary rather than keeping a
parallel compatibility path.
