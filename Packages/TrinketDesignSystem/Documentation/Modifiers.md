# Modifier API reference

Use shared APIs for product colors, typography, glass, and recurring chrome.
Ordinary native layout and control composition remain appropriate, including plain
buttons and system toolbar styling.

| Modifier / API | Use for |
|----------------|---------|
| `.trinketScreenBackground()` | Shared tab/screen canvas (`TrinketDesign.Colors.canvas`) |
| `.trinketSurface(_:)` | Panels, cards, rows, selected/disabled/warning/reward states |
| `.trinketMaterial(_:)` | `.bottomBar` / `.homesteadFooter`: regular glass; `.rewardReveal`: accent-tinted regular glass; `.subtleOverlay`: standard ultra-thin material with a semantic stroke |
| `.trinketGlassChip(_:)` | Regular-glass capsules; `.standard` / `.emphasis` select shared padding and emphasis stroke |
| `.trinketTypography(_:)` | Scalable text hierarchy (`TypographyRole`) |
| `.trinketCardSurface(showsStroke:)` | Card identity tiles (`showsStroke` adds the artwork clip + subtle stroke) |
| `.trinketArtworkPickerSelectionBorder(isSelected:color:lineWidth:)` | Selection border around artwork picker cards |
| `.trinketLockedCardEffect(isLocked:cornerRadius:)` | Subtle desaturation + opaque content blur, larger opaque paper lock with ink edge contrast |
| `TrinketDesign.Layout.collectionGridItems` / `.partyPickerGridItems` / `.hubGridItems(for:)` | Shared collection, party-picker, and size-class hub grids (via `Spacing`) |
| `TrinketDesign.Layout.collectionShelfPreviewLimit` | Peek-shelf card count for Collection / party shelves |
| `.trinketPrimaryActionButton()` | Primary CTAs (`.glassProminent`, single `GlassButtonModifier`) |
| `.trinketSecondaryActionButton()` | Secondary CTAs (`.glass`) |
| `.trinketIconButton()` | Circular glass icon controls with stable accessibility identifiers |
| `.trinketArtworkCardButtonStyle()` | Press-scale feedback for card buttons; accepts optional `pressedScale` (default `0.99`), with `TrinketMotion.Interaction.choiceCardPressedScale` for talent choices |
| `.trinketCardLabelSpace(_:)` | Reserved label height under cards |
| `.trinketAccessibilityIdentifier(_:)` | Optional test identifier passthrough |
| `.optionalMatchedTransitionSource(id:in:)` | Matched transitions with an optional namespace |
| `.trinketCollectionShelfCardWidth()` | Peek-shelf card width |
| `.trinketFittedText()` / `.trinketSingleLineFittedText()` | Native text shrinking/wrapping |
| `Text(balanced:)` | Widow-proof titles |
| `TrinketWalletGrid` / `TrinketWalletResourcePill` / `TrinketCompactResourceChip` | Wallet grid and resource pills/chips |
| `.trinketCenteredPrimaryAction()` | Half-width, centered layout for a lone screen primary action |
| `.trinketOnArtText(_:)` | Paper foreground + ink shadows on hero art |
| `.trinketBottomArtworkBlend(color:)` | Bottom-edge blend into a destination color (defaults to canvas) |
| `.trinketSensoryFeedback(_:trigger:enabled:)` | Gate `.sensoryFeedback` on Options haptics toggle |

Native toolbar buttons use the system-provided container without custom glass
button styling. Reserve `.trinketIconButton()` for controls outside native toolbars.

Glass chrome routes through `.glassEffect` inside this package only.

Artwork blends transition full-bleed art into the surface below. Use `.trinketBottomArtworkBlend()` where art meets a lower surface. Keep text-only contrast treatments such as `.trinketOnArtText(_:)` when they serve a separate readability purpose.

Platform API notes: [Apple platform reference](../../../Docs/Platform/ApplePlatformReference.md). Fluid motion: [apple-design skill](../../../.agents/skills/apple-design/SKILL.md) (`TrinketMotion`). Standing stack rules: [Architecture.md](../../../Docs/Platform/Architecture.md).

Wallet resource pills accept either a numerical balance or a formatted value for
production rates and comparisons. Amounts default to the primary text color;
formatted values accept `valueColor` for semantic states such as insufficient
Homestead costs, which use `TrinketDesign.Colors.destructive`.
