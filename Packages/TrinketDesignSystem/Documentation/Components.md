# Component ownership

| File | Role |
|------|------|
| `TrinketDesign.swift` | Colors, `Opacity`, `Spacing`/`Layout`/`Bars`, card shape, placeholder styles |
| `DesignAssetColors.swift` | Package-private semantic color loader (`Bundle.module`); feature code must use `TrinketDesign.Colors` instead |
| `Resources/DesignColors.xcassets` | Theme, keyword, encounter, placeholder, resource, and chapter color sets |
| `VisualFoundation.swift` | Screen background, surface/material roles, typography, glass chips (default specs with per-role overrides) |
| `OnArtText.swift` | On-art text styling (`.trinketOnArtText`) |
| `ArtworkBlend.swift` | Bottom-edge artwork blend into a destination color (`.trinketBottomArtworkBlend()`; defaults to canvas, pass the actual surface below the art) |
| `Keyword+VisualStyle.swift` | Color + game icon per Keyword (uses `Opacity` tokens); `gold` aliases accent and `thorns` aliases Physical (no dedicated assets); `beneficialStatus`/`negativeStatus` are feedback-owned values sharing the type |
| `GameIcon.swift`, `GameIconImage.swift` | SF Symbol identity (`sf:` authored IDs, bare names resolve identically) and native SwiftUI rendering |
| `HomesteadResource+Color.swift` | Homestead resource tint resolution (gold resolves to the theme accent; icon/displayName live in `TrinketFeatureSupport/Models/Homestead.swift`) |
| `CardModifiers.swift` | Card surfaces, selection border, lock effect, label space |
| `GlassButtons.swift` | Glass buttons (prominent/secondary/icon via `.buttonStyle(.glass*)`), centered primary layout, press feedback |
| `ViewGuards.swift` | Optional test identifiers, sensory-feedback gate, optional matched-transition source |
| `ExperienceBar.swift` | XP/level progress bar |
| `TrinketMotion.swift` | Motion recipes shared by multiple product features (`Interaction`/`Reward`/`Shine`/`Content`/`Screen` families: animations plus scales, staggers, delays, and durations) |
| `PlaceholderArtwork.swift` | Unified placeholder wash + symbol (scaled, `Opacity.placeholderWash`) |
| `WalletFormatting.swift`, `WalletBump.swift`, `WalletGrid.swift`, `WalletPill.swift`, `WalletChip.swift` | Wallet amount formatting (incl. `+` prefix), increase bump, grid layout, resource pills/chips (formatted-value pills do not animate amount changes) |
| `KeywordPlasmaBackground.swift`, `KeywordPlasmaDiffusion.metal` | Keyword-tinted plasma shader (Reduce Motion aware with a static fallback, single-source rendering; first two keywords win) |
| `TrinketShineText.swift` | Shared text shine renderer (`trinketShineText(colors:)`): a seamless 14.4-second loop with a static Reduce Motion fallback |
| `TrinketRarityLabel.swift` | Rarity badge with shine (Reduce Motion handling inherited from shine text) |
| `TrinketText.swift` | Widow prevention for titles (`Text(balanced:)`) and native shrinking/wrapping text (`.trinketFittedText()`) |
| `PresentationVisibility.swift` | Retained/reveal opacity, touch, and accessibility exposure under one semantic visibility input, plus decorative-motion parking (`trinketDecorativeMotion`, AND-composed so descendants cannot re-enable under a suppressed ancestor) |
| `DesignSystemPreview.swift` | Debug-only gallery (`#if DEBUG`, never ships) |
