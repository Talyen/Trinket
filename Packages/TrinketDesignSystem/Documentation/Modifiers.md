# Modifier API reference

Route recurring chrome through these modifiers — do not call raw SwiftUI styling APIs from feature views.

| Modifier / API | Use for |
|----------------|---------|
| `.trinketScreenBackground()` | Shared tab/screen canvas (`TrinketDesign.Colors.canvas`) |
| `.trinketSurface(_:)` | Panels, cards, rows, selected/disabled/warning/reward states |
| `.trinketMaterial(_:)` | Bottom bars, popovers, reward reveals; modal uses solid surface; toolbar passes through |
| `.trinketGlassChip()` | Glass capsule chips via shared `TrinketGlassBackgroundModifier` |
| `.trinketTypography(_:)` | Scalable text hierarchy (`TypographyRole`) |
| `.trinketCardSurface()` | 3:4 card identity tiles |
| `ArtworkPickerSelectionBadge` / `.trinketArtworkPickerSelectionBorder(isSelected:color:)` | Selected artwork picker checkmark + stroke |
| `.trinketLockedCardEffect(isLocked:cornerRadius:)` | Subtle desaturation + opaque content blur, larger opaque paper lock with ink edge contrast |
| `TrinketDesign.Layout.collectionGridItems` / `.partyPickerGridItems` / `.hubGridItems(for:)` | Shared collection, party-picker, and size-class hub grids (via `Spacing`) |
| `TrinketDesign.Layout.collectionShelfPreviewLimit` | Peek-shelf card count for Collection / party shelves |
| `.trinketPrimaryActionButton()` | Primary CTAs (`.glassProminent`, single `GlassButtonModifier`) |
| `.trinketSecondaryActionButton()` | Secondary CTAs (`.glass`) |
| `.trinketIconButton()` | Circular glass icon controls with stable accessibility identifiers |
| `.trinketArtworkCardButtonStyle()` / `.trinketSelectionCardButtonStyle()` | Press-scale feedback for card buttons |
| `.trinketCardLabelSpace(_:)` | Reserved label height under cards |
| `.trinketAccessibilityIdentifier(_:)` | Optional test identifier passthrough |
| `.optionalMatchedTransitionSource(id:in:)` | Matched transitions with an optional namespace |
| `.cardArtworkSurface()` | Card clipping + stroke (`TrinketDesign.cardShape` single source) |
| `collectionShelfCardWidth()` | Peek-shelf card width |
| `.trinketFittedText()` / `.trinketSingleLineFittedText()` | Native text shrinking/wrapping |
| `Text(balanced:)` | Widow-proof titles |
| `TrinketWalletGrid` / `TrinketWalletResourcePill` / `TrinketCompactResourceChip` | Wallet grid and resource pills/chips |
| `.trinketCenteredPrimaryAction()` | Half-width, centered layout for a lone screen primary action |
| `.trinketQuietTapButtonStyle()` | Compatibility alias for `.buttonStyle(.plain)`; prefer the native style directly |
| `.trinketOnArtText(_:)` | Paper foreground + ink shadows on hero art |
| `.trinketArtworkBlend(_:)` | Optional `.bottom` blend into a semantic destination surface; defaults to `.none` |
| `.trinketSensoryFeedback(_:trigger:enabled:)` | Gate `.sensoryFeedback` on Options haptics toggle |

Native toolbar buttons use the system-provided container without custom glass
button styling. Reserve `.trinketIconButton()` for controls outside native toolbars.

Glass chrome routes through `.glassEffect` inside this package only.

Artwork blends provide a transition into destination surfaces. Use `.bottom(into:)` for full-bleed art meeting a lower surface, and `.none` when artwork should retain a crisp edge. Keep text-only contrast treatments such as `.trinketOnArtText(_:)` when they serve a separate readability purpose.

Platform API notes: [iOS26AppleReference.md](../../../Docs/Platform/iOS26AppleReference.md). Fluid motion: [apple-design skill](../../../.agents/skills/apple-design/SKILL.md) (`TrinketMotion`). Standing stack rules: [Architecture.md](../../../Docs/Platform/Architecture.md).

Wallet resource pills accept either a numerical balance or a formatted value for
production rates and comparisons. Amounts default to the primary text color;
formatted values accept `valueColor` for semantic states such as insufficient
Homestead costs, which use `TrinketDesign.Colors.destructive`.
