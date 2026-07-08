# App Visual Foundation

This document turns the v2 visual reference boards into implementation guidance for Trinket's shared SwiftUI design system. The boards remain useful for taste and proportion; this doc owns the durable decisions that should become code, tests, and review criteria.

## Source References

Reference PNG boards are described in `Docs/Design/StyleGuide/VisualReferences/README.md` (including the v2 game-compatible pass). Those images are not committed to the repository; this document and `TrinketDesignSystem` source are the implementation north star. When boards are available locally, use them for taste and proportion:

- `01-north-star-overview-v2.png` — overall style direction and scope.
- `02-theme-presets-v2.png` — archived exploratory board; not part of the shipped visual system.
- `03-surfaces-materials-v2.png` — surface roles, material rules, state treatment, and Reduce Transparency fallback.
- `04-elemental-feedback-v2.png` — Keyword tinting, combat feedback, particles, and motion guidance.
- `05-screen-fragments-v2.png` — representative app-screen adoption across current product flows.

The first-pass boards in `Docs/Design/StyleGuide/VisualReferences/` are exploratory. Prefer v2 for implementation unless a newer pass supersedes it.

## Product Fit

The visual foundation must preserve Trinket's current product structure:

- Persistent tabs: Play, Collection, Homestead, Search, Options.
- Collection owns Heroes, Pets, and Inventory.
- Play owns Chapter Journey, Stage Select, active encounter actions, and Battle entry.
- Battle is idle, automatic, and 2D card-art based: Enemy, Hero, and Pet art regions with anchored health bars.
- Rare battle actions live in native toolbar/menu chrome; do not introduce a manual skill hotbar or a Battle tab.
- Future battle spectacle should use SwiftUI/card-art presentation: floating combat text, Keyword particles, card flash/recoil/lunge, health-bar trails, Skill ability-art callouts on the caster, and full-screen Hero/Pet Ultimate cinematics (video when available, ability-art fallback otherwise).

## Appearance

App chrome uses Apple semantic system colors through a single neutral palette (`ThemePalette.apple`). Do not invent one-off screen colors in feature views.

Players choose appearance via **System**, **Light**, or **Dark** in Options (`OptionsStore.appearance`). Tests can override with the `-appearance` launch argument. The palette defines:

- Base app background from Apple semantic system colors.
- Secondary background from Apple semantic system colors.
- Elevated background from Apple semantic system colors.
- Panel/card surface from Apple semantic system colors.
- Overlay/scrim color.
- Subtle stroke.
- Neutral accent color.
- Shadow behavior.
- Default material preference.

Keyword identities and card art carry the strong hues; chrome stays color-neutral and readable in every appearance mode.

## Background Modes

Expose semantic background modes so screens request intent rather than colors:

| Mode | Use |
|---|---|
| `playJourney` | Chapter Journey, Stage Select, and premium Play surfaces. |
| `collection` | Heroes, Pets, Inventory overview, and card shelves. |
| `denseList` | Search, Inventory lists, long text, and utility-heavy surfaces. |
| `homestead` | Homestead wallet, project cards, and upgrade surfaces. |
| `battle` | Battle art regions and subdued combat atmosphere. |
| `modal` | Sheets, overlays, popovers, and temporary focus states. |

Default composition:

1. Apple semantic system background.
2. Apple semantic system surfaces.
3. Neutral strokes and accents from `ThemePalette.apple`.
4. Optional scrim for artwork or modal focus.
5. Keyword or gameplay tint only when semantically meaningful.

Dense content should stay quiet and readable. Play, Battle, Victory, rewards, and Homestead can carry stronger atmosphere.

## Surface Roles

Create semantic surface roles in `TrinketDesignSystem` and migrate screens to modifiers/components that express role:

| Role | Use |
|---|---|
| `base` | Primary panels and screen sections. |
| `secondary` | Subsections and lower-emphasis grouping. |
| `elevated` | Important content, pop-in panels, and focused controls. |
| `card` | 3:4 combatant/item/ability cards and identity tiles. |
| `denseRow` | Inventory, Search, requirements, and compact list rows. |
| `selected` | Active category, selected combatant/item, or current stage. |
| `disabled` | Locked stages, locked cards, unavailable controls. |
| `warning` | Destructive/warning regions and risky actions. |
| `reward` | Victory, reward reveal, positive milestone feedback. |
| `modal` | Sheet bodies and modal content containers. |
| `popover` | Menus, tooltips, compact contextual information. |

State treatment should use border, glow, icon, opacity, and foreground changes before changing the entire fill. Locked content should remain structured and visible but muted, matching the established locked-card direction.

Keep the existing card-radius default: `16` points. Compact controls can use `8` or `12` point radii.

## Material Rules

Use SwiftUI Material and Liquid Glass intentionally. iOS 26 guidance and Trinket audit: `Docs/Platform/iOS26AppleReference.md`, `Docs/Platform/iOS26StackAudit.md`.

- Use **Liquid Glass** (`.glassEffect`) for selective custom chrome — combat feedback chips, wallet/status pills, high-value overlays — via `TrinketDesignSystem` modifiers, not raw feature-view calls.
- Use classic **Material** or solid surfaces where glass would distract from card art and dense lists.
- Prefer solid themed surfaces for Collection, Inventory, Search, Options, detail sections, and other dense content.
- Avoid stacking multiple translucent materials or glass-on-glass layers.
- Respect Reduce Transparency by resolving material roles to solid themed surfaces (see `GlassChipModifier` pattern).
- Let system tab bars, toolbars, and sheets adopt Liquid Glass automatically; avoid custom backgrounds that fight the system material.
- Route all glass and material styling through `TrinketDesignSystem`; `Scripts/check-ui-style.sh` enforces this.

## Typography And Spacing

Define typography roles that map to Apple-native scalable text styles:

- `screenTitle`
- `sectionTitle`
- `cardTitle`
- `body`
- `secondaryBody`
- `caption`
- `badge`
- `button`
- `statValue`
- `tooltip`
- `navigation`

Use weight, hierarchy, and layout rhythm for fantasy flavor. Do not use decorative fonts for core UI text.

Define semantic spacing tokens:

- `extraSmall`
- `small`
- `medium`
- `large`
- `extraLarge`
- `screenMargin`
- `cardPadding`
- `sectionGap`
- `rowGap`
- `modalPadding`
- `toolbarPadding`

Screens should use semantic spacing tokens instead of inventing local constants unless the layout has a documented reason.

## Keyword And Elemental Styling

`Keyword.visualStyle` remains the source of truth for Keyword identity. Expand it from color + symbol into a richer style model:

- Primary tint.
- Secondary tint if useful.
- Glow color.
- Subtle background tint.
- Border/accent color.
- SF Symbol name.
- Readable foreground strategy.
- Optional particle style.

Every Keyword must remain covered:

```text
Physical, Burn, Stun, Block, Armor, Health, Gold, Holy, Poison, Bleed,
Leech, Nature, Freeze, Dodge, Purge, Mana, Death's Door
```

Use Keyword styling for ability chips, item affix badges, status badges, selected filters, reward highlights, inline descriptions, combat log icons, and battle feedback. Do not introduce one-off Keyword colors in feature views.

## Battle Feedback And Motion

Battle presentation should remain SwiftUI/card-art based.

Recommended feedback vocabulary:

- Direct damage: floating number with Keyword icon and tint.
- DoT tick: smaller repeated floating number for Burn, Poison, and Bleed.
- Heal: positive Health feedback.
- Block: shield icon with blocked amount.
- Armor: mitigation chip or reduced-damage cue.
- Mana/Gold: resource gain feedback.
- Stun/Freeze: skipped-action callout.
- Dodge/Purge: utility callout.

Recommended VFX:

- Low-count Keyword particles around the affected card.
- Card flash, lunge, recoil, or shake.
- Health-bar fill and trailing damage/heal animation.
- Skill cast: short caster-anchored ability-art callout (~0.5s soft-hold), with hit chips still on the target.
- Ultimate cast (Hero/Pet only): full-screen cinematic while combat is held; prefer preloaded 9:16 video (source assets may vary; crop to 9:16 for display), fall back to ability card art until video exists; on dismiss, immediately resume combat and show damage/effects. Enemy Ultimates do not take over the screen.
- Options preference controls whether Ultimate cinematics can be skipped (always / never / after first view).

Reduce Motion should replace movement-heavy feedback with fades, static glows, or lower-count effects, and should prefer the static Ultimate art fallback over video. Do not use 3D models or a 3D battle scene for these effects.

## Accessibility Rules

- Use semantic text foreground styles by default.
- Keep custom foregrounds high contrast on themed surfaces.
- Pair color with icon and label for state or mechanics.
- Respect Dynamic Type.
- Respect Reduce Motion for particles, hit motion, and Ultimate transitions.
- Respect Reduce Transparency for materials.
- Keep touch targets appropriate for iPhone portrait use.
- Ensure VoiceOver exposes exact values for health, resources, locked states, and actionable controls.

## Implementation Plan

### Phase 1 — Design-System Primitives

Implement reusable types in `Packages/TrinketDesignSystem`:

- `ThemePalette` and semantic color tokens.
- Background modes and composition modifiers.
- Surface roles and state-aware modifiers.
- Material roles with Reduce Transparency fallback.
- Typography and spacing roles.
- Expanded Keyword visual styles.
- Lightweight atmosphere/particle primitives that are opt-in.

Add focused `TrinketDesignSystemTests` for palette completeness, Keyword coverage, and pure-data role resolution.

### Phase 2 — App Wiring

Update app wiring:

- Keep `OptionsStore.appearance` persisted in `UserDefaults`.
- Keep `AppEnvironment` `-appearance` parsing for tests and simulator launches.
- Apply the active appearance through `preferredColorScheme` at the app shell.

### Phase 3 — Representative Adoption

Migrate a first, reviewable slice:

- Root app shell and tab background.
- Options form and appearance picker.
- Collection overview, Heroes/Pets grids, Inventory preview/cards.
- Play journey/stage select background, active stage card, locked rows.
- Search and Inventory dense-list surfaces.
- Homestead wallet/project cards.
- Battle root background and overlay material roles without changing combat rules.

Keep behavior and navigation unchanged.

### Phase 4 — Battle Feedback Slice

After the foundation is stable, implement battle polish separately:

- Floating combat text improvements.
- Keyword particles and feedback bursts.
- Card flash/recoil/lunge states.
- Health-bar trailing damage/heal animation.
- Skill caster-anchored ability-art callout and Ultimate cinematic overlay — see **`Docs/Design/BattleSpectaclePlan.md`** (R-008 / R-011) for motion APIs, session timing, video preload, and Options skip policy.

This phase should have focused unit or presentation tests where feasible and smoke coverage for Battle flow stability.

### Phase 5 — Documentation And Verification

Update docs as implementation names settle:

- `Docs/Architecture.md` for expanded `TrinketDesignSystem` ownership.
- `Docs/Design/CoreDesignConcepts.md` for durable visual and battle-presentation principles.
- `Docs/Design/AppleNativeGuidelines.md` for Trinket-specific native chrome rules and deprecated-pattern deny list.
- `Docs/Design/StyleGuide/VisualReferences/README.md` when a newer visual pass supersedes v2.

Recommended verification for Phase 1-3:

```sh
./Scripts/build.sh
./Scripts/test.sh unit
./Scripts/test.sh smoke
./Scripts/check-ui-style.sh
```

Also manually launch representative screens with each appearance mode via `-appearance`.
