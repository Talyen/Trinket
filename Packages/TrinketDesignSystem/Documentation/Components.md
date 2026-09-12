# Component ownership

| File | Role |
|------|------|
| `TrinketDesign.swift` | Colors, `Opacity`, `Spacing`/`Layout`/`Bars`, card shape, placeholder styles |
| `DesignAssetColors.swift` | Package-private semantic color loader (`Bundle.module`); feature code must use `TrinketDesign.Colors` instead |
| `Resources/DesignColors.xcassets` | Theme, keyword, encounter, placeholder, resource, and chapter color sets |
| `VisualFoundation.swift` | Background modes, surface roles, spacing tokens (table-driven specs) |
| `HeroScrim.swift` | On-art text styling (`.trinketOnArtText`) |
| `ArtworkBlend.swift` | Optional semantic bottom-edge artwork blending |
| `Keyword+VisualStyle.swift` | Color + game icon per Keyword (uses `Opacity` tokens) |
| `GameIcon.swift`, `GameIconImage.swift` | SF Symbol identity, legacy identifier translation, and native SwiftUI rendering |
| `HomesteadResource+Color.swift` | Homestead resource tint resolution (gold resolves to the theme accent) |
| `Modifiers.swift` | Semantic view modifiers for backgrounds, surfaces (single glass button path) |
| `ExperienceBar.swift` | XP/level progress bar |
| `TrinketMotion.swift` | Motion recipes shared by multiple product features (`static let` animations) |
| `CardArtwork.swift` | Card clipping and stroke (`TrinketDesign.cardShape` single source) |
| `PlaceholderArtwork.swift` | Unified placeholder wash + symbol (scaled, `Opacity.placeholderWash`) |
| `WalletResources.swift` | Wallet grid and resource pills/chips (shared compact formatting, fixed layout threshold; chips accept numeric amounts or formatted comparison values) |
| `KeywordPlasmaBackground.swift` | Keyword-tinted plasma shader (Reduce Motion aware with a static fallback, single-source rendering) |
| `TrinketShineText.swift` | Shared text shine renderer (`trinketShineText(colors:)`): four text widths, a seamless 14.4-second loop, and a static Reduce Motion fallback |
| `TrinketRarityLabel.swift` | Rarity badge with shine (Reduce Motion aware) |
| `TextBalance.swift` | Widow prevention for titles (`Text(balanced:)`) |
| `PresentationVisibility.swift` | Retained/reveal opacity, touch, and accessibility exposure under one semantic visibility input |
| `TextFitting.swift` | Native shrinking/wrapping text composition (`.trinketFittedText()`) |
| `DesignSystemPreview.swift` | Debug-only gallery (`#if DEBUG`, never ships) |
