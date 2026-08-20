# AgentContext cards

Path-routed domain guides. `./Scripts/agent-context.sh` attaches them from
`Scripts/change-classification.sh` (there is no YAML catalog). Cards hold
cross-package exceptions, not restated root policy. Platform docs own architecture
and testing; nested `AGENTS.md` files own local hard stops.

| Card | Typical trigger |
|------|-----------------|
| [battle.md](battle.md) | `BattleEngine`, `TrinketBattleFeature`, `TrinketAppState` |
| [persistence.md](persistence.md) | `TrinketPersistence` |
| [content-and-manifests.md](content-and-manifests.md) | manifests, content catalogs, `project.yml` |
| [swiftui-features.md](swiftui-features.md) | `Trinket/Features`, `TrinketUITests`, `TrinketFeatureSupport` |
| [audio.md](audio.md) | `TrinketAppState` audio paths |
| [ci-and-project-generation.md](ci-and-project-generation.md) | `Scripts/`, `.github/`, `project.yml` |
| [ci-diagnostics.md](ci-diagnostics.md) | **Lazy:** load only after a test/CI failure |

Apple design procedure: [apple-design skill](../Skills/apple-design/SKILL.md) (also attached for DesignSystem and feature UI). Cursor glob rule `.cursor/rules/design-system-colors.mdc` enforces color routing independently of this catalog. Automated intent recovery (`why` skill) searches these cards alongside `Docs/Product/Decisions.md` and package unit tests before modifying core domain rules.
