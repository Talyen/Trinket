# Component ownership

| File | Role |
|------|------|
| `TrinketDesign.swift` | Colors, `Opacity`, `Spacing`/`Layout`/`Bars`, card shape, placeholder styles |
| `DesignAssetColors.swift` | Package-private semantic color loader (`Bundle.module`); feature code must use `TrinketDesign.Colors` instead |
| `Resources/DesignColors.xcassets` | Theme, keyword, encounter, placeholder, resource, and chapter color sets |
| `VisualFoundation.swift` | Screen background, surface/material roles, typography, glass chips (table-driven specs) |
| `HeroScrim.swift` | On-art text styling (`.trinketOnArtText`) |
| `ArtworkBlend.swift` | Bottom-edge artwork blend into a destination color (`.trinketBottomArtworkBlend()`) |
| `Keyword+VisualStyle.swift` | Color + game icon per Keyword (uses `Opacity` tokens) |
| `GameIcon.swift`, `GameIcon+Legacy.swift`, `GameIconImage.swift` | SF Symbol identity, legacy identifier translation, and native SwiftUI rendering |
| `HomesteadResource+Color.swift` | Homestead resource tint resolution (gold resolves to the theme accent) |
| `Modifiers.swift` | Semantic view modifiers for backgrounds, surfaces, glass buttons (prominent/secondary), press feedback |
| `ExperienceBar.swift` | XP/level progress bar |
| `TrinketMotion.swift` | Motion recipes shared by multiple product features (`static let` animations) |
| `PlaceholderArtwork.swift` | Unified placeholder wash + symbol (scaled, `Opacity.placeholderWash`) |
| `WalletResources.swift` | Wallet grid and resource pills/chips (shared compact formatting; constrained columns equalize above a 60pt minimum, 44pt artwork-only) |
| `KeywordPlasmaBackground.swift`, `KeywordPlasmaDiffusion.metal` | Keyword-tinted plasma shader (Reduce Motion aware with a static fallback, single-source rendering) |
| `TrinketShineText.swift` | Shared text shine renderer (`trinketShineText(colors:)`): a seamless 14.4-second loop with a static Reduce Motion fallback |
| `TrinketRarityLabel.swift` | Rarity badge with shine (Reduce Motion handling inherited from shine text) |
| `TrinketText.swift` | Widow prevention for titles (`Text(balanced:)`) and native shrinking/wrapping text (`.trinketFittedText()`) |
| `PresentationVisibility.swift` | Retained/reveal opacity, touch, and accessibility exposure under one semantic visibility input |
| `DesignSystemPreview.swift` | Debug-only gallery (`#if DEBUG`, never ships) |
