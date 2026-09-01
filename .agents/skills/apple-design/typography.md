# Typography

Use this reference for font choice, optical sizing, tracking, leading, and text hierarchy. Apple’s UI typography treats type as changing shape with size, not as one fixed style scaled up and down.

## Type rules

- Tracking (letter-spacing) is size-specific. Large display text wants negative tracking because letters read too far apart as they grow; small text wants slightly positive tracking for legibility. Never use one tracking value for every size. Tighten headings and leave body copy near `0`.
- Leading (line-height) tracks size inversely: tighter on large headings, looser on body copy. Increase it for scripts with tall ascenders/descenders; tighten it for dense information-heavy UI.
- Build hierarchy from weight, size, and leading together, not size alone. Weight adds presence without consuming more space.
- Use Dynamic Type text styles and `@ScaledMetric` where a visual metric should follow type — they are free native behavior, not accommodations. Do not add layouts whose only job is re-flowing at accessibility text sizes (PD-014).
- Start with the platform system font. It already ships optical sizing, tracking tables, and legibility tuning. Use a custom face only with a clear reason.

In Trinket, use `.trinketTypography(_:)` and the existing typography roles. Add a
role only when the hierarchy has a distinct current use; do not introduce raw
`.font(.system(size:))` copy styling in feature views.

## Review questions

- Are labels specific and concise enough to avoid wrapping surprises?
- Do weight, contrast, leading, and spacing do the work before decorative styling is added?

Apple reference: [Typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography/).
