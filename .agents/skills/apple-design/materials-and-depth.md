# Materials and depth

Start from existing semantic surfaces in
[semantic modifiers](../../../Packages/TrinketDesignSystem/Documentation/Modifiers.md),
choosing a material when it establishes hierarchy or preserves context.

Liquid Glass belongs on floating controls and navigation, while standard
materials and solid semantic surfaces organize dense content beneath it
(preserving documented game-specific uses such as reward reveals). Regular glass
is a good default; clear glass works best over rich backgrounds with verified
label contrast and appropriate dimming when bright.

- Check text and controls over real artwork, including busy backgrounds and
  scrolling content; prefer fixing legibility with a shared surface or contrast
  treatment over stacking blur and shadows.
- Use a scrim for modal tasks; leave surrounding content visibly usable for
  non-blocking panels.
- Avoid stacking translucent surfaces when an opaque or shared material expresses
  the hierarchy more clearly.
- Preserve native scroll-edge separation beneath floating controls (the soft top
  effect on iOS 26+ and native older-OS chrome from
  [SwiftUI feature guidance](../../../Docs/AgentContext/swiftui-features.md) and
  the app root) rather than stacking custom fades.
- Prefer native or shared presentation transitions unless a custom transition
  adds clear interaction value.

Platform reference: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
