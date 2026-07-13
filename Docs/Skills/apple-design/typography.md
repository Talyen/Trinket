# Typography

Use this reference for font choice, Dynamic Type, optical sizing, tracking, leading, text hierarchy, and layouts that must survive larger text. Apple’s UI typography treats type as changing shape with size, not as one fixed style scaled up and down.

## Type rules

- Tracking (letter-spacing) is size-specific. Large display text wants negative tracking because letters read too far apart as they grow; small text wants slightly positive tracking for legibility. Never use one tracking value for every size. Tighten headings and leave body copy near `0`.
- Leading (line-height) tracks size inversely: tighter on large headings, looser on body copy. Increase it for scripts with tall ascenders/descenders; tighten it for dense information-heavy UI.
- Build hierarchy from weight, size, and leading together, not size alone. Weight adds presence without consuming more space.
- Respect the user’s text-size setting (Dynamic Type). Scale layout with the text; use relative spacing (`rem`/`em` or SwiftUI’s Dynamic Type-aware APIs), not fixed pixels that break when type grows.
- Start with the platform system font. It already ships optical sizing, tracking tables, and legibility tuning. Use a custom face only with a clear reason.

```css
:root { font: 100%/1.5 system-ui, sans-serif; }

.display {
  font-size: clamp(2rem, 5vw, 4rem);
  line-height: 1.05;
  letter-spacing: -0.02em;
  font-optical-sizing: auto;
}
```

The example shows the optical relationship; in Trinket prefer SwiftUI’s system font styles and `TrinketDesignSystem` typography primitives.

## Review questions

- Does the hierarchy remain obvious when body and accessibility text sizes increase?
- Are labels specific and concise enough to avoid wrapping surprises?
- Do weight, contrast, leading, and spacing do the work before decorative styling is added?
