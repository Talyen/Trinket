# Materials and depth

Use existing semantic surfaces from
[TrinketDesignSystem](../../../Packages/TrinketDesignSystem/README.md).
Choose a material because it establishes hierarchy or preserves context, not
because every screen needs glass.

- Inspect text and controls over the actual artwork, including busy backgrounds
  and scrolling content. Resolve poor legibility through the shared surface or
  contrast treatment before adding layers of blur, shadow, and tracking.
- Use a scrim when the task is modal. A non-blocking panel should leave its
  surrounding content visibly usable.
- Keep content and controls visually distinct. Avoid stacking translucent surfaces
  when an existing opaque or shared material expresses the hierarchy more clearly.
- Prefer the native or shared presentation transition. Custom blur/scale animation
  needs a specific interaction benefit; it is not a requirement for material entry.

Review whether the overlay makes the current action clear, keeps labels readable,
and leaves an obvious way to dismiss it.

Platform reference: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
