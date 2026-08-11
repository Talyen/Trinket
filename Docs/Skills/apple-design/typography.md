# Typography

Use this reference for font choice, Dynamic Type, optical sizing, tracking, leading, text hierarchy, and layouts that must survive larger text. Apple’s UI typography treats type as changing shape with size, not as one fixed style scaled up and down.

## Type rules

- Tracking (letter-spacing) is size-specific. Large display text wants negative tracking because letters read too far apart as they grow; small text wants slightly positive tracking for legibility. Never use one tracking value for every size. Tighten headings and leave body copy near `0`.
- Leading (line-height) tracks size inversely: tighter on large headings, looser on body copy. Increase it for scripts with tall ascenders/descenders; tighten it for dense information-heavy UI.
- Build hierarchy from weight, size, and leading together, not size alone. Weight adds presence without consuming more space.
- Respect the user’s text-size setting. Use Dynamic Type text styles,
  `@ScaledMetric` where a nearby visual metric must follow type, and layouts that can
  grow or scroll rather than fixed point-sized bands.
- Start with the platform system font. It already ships optical sizing, tracking tables, and legibility tuning. Use a custom face only with a clear reason.

In Trinket, use `.trinketTypography(_:)` and the existing typography roles. Add a
role only when the hierarchy has a distinct current use; do not introduce raw
`.font(.system(size:))` copy styling in feature views.

## Review questions

- Does the hierarchy remain obvious when body and accessibility text sizes increase?
- Are labels specific and concise enough to avoid wrapping surprises?
- Do weight, contrast, leading, and spacing do the work before decorative styling is added?

Apple reference: [Typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography/).
