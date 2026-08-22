# Materials and depth

Use this reference for translucent surfaces, glass, blur, toolbars, sheets, scrims, overlays, shadows, vibrancy, and floating chrome. Translucent materials should create a functional layer and hierarchy without stealing focus.

## Material hierarchy

- Build nav bars, toolbars, and sheets as system or DesignSystem layers with content
  scrolling underneath when that hierarchy suits the screen.
- Encode hierarchy with material weight: darker/heavier materials separate structural regions such as sidebars; lighter materials draw attention to interactive elements such as buttons.
- Never stack a light translucent surface on another light translucent surface; legibility collapses.
- Make larger surfaces read as thicker with stronger blur and deeper shadow than small chips. Use a heavier shadow over busy or text-heavy content and a lighter one over a plain background.
- Use vibrancy and contrast for text over changing backgrounds: avoid flat gray text, prefer higher contrast and slightly heavier weight, with a small tracking bump when needed. Put saturated color on a solid layer rather than the translucent foreground.

## Focus, flow, and depth

- **Dim to focus:** a modal task pairs its surface with a dimming scrim and pushes the background back/down.
- **Separate to preserve flow:** a parallel, non-blocking panel uses translucency and offset without a scrim.
- For stacked sheets, progressively dim and push back each parent layer.
- Replace a hard divider under sticky floating chrome with a small blur or gradient mask where content meets the surface; use this only where floating UI actually overlaps content.
- Materialize rather than merely fade. On entry/exit, animate blur radius and scale together so the surface reads as a real material arriving.

Materials, colors, and glass route through `TrinketDesignSystem`
(`check-ui-style.sh` enforces this); see the
[TrinketDesignSystem README](../../../Packages/TrinketDesignSystem/README.md)
for tokens and reduced-transparency handling.

## Review questions

- Does the surface clarify what is structural versus interactive?
- Can text and controls remain legible over the background at every scroll position and appearance?
- Is a scrim present only when the task should block or focus attention?
- Do blur, scale, shadow, and offset communicate physical depth without decorative excess?

Apple reference: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
