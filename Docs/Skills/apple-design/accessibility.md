# Accessibility and reduced motion

Use this reference for reduced motion, reduced transparency, increased contrast, vestibular safety, and interaction choices that must work across abilities and contexts. Reduced motion does not mean no feedback; it means a gentler, non-vestibular equivalent.

## Independent user preferences

Respond to each signal independently and bake the behavior into components:

- **Reduced motion:** replace slides, springs, parallax, elastic effects, and overshoot with short opacity cross-fades or static transitions. Keep opacity and color changes that aid comprehension.
- **Reduced transparency:** make translucent surfaces frostier or solid by raising background opacity and dropping blur.
- **Increased contrast (`prefers-contrast: more`):** use near-solid backgrounds with a defined, contrasting border.

```css
@media (prefers-reduced-motion: reduce) {
  .sheet { transition: opacity 200ms ease; transform: none !important; }
}

@media (prefers-reduced-transparency: reduce) {
  .toolbar { background: white; backdrop-filter: none; }
}
```

In SwiftUI, map these outcomes to the platform’s accessibility environment values and the project’s design-system variants; do not add a web-only compatibility layer to the app.

## Vestibular and visual safety

- Avoid full-viewport moving backgrounds and slow looping oscillations (around `0.2 Hz`, one cycle per five seconds).
- Avoid abrupt brightness jumps; ease dark↔light theme changes.
- Make large moving objects semi-transparent while they travel.
- Fade large surfaces out during a large reposition and back in after settling when that reduces visual strain.
- Preserve the same status, completion, warning, and error meaning when motion or material is removed.

## Interaction review

- Ensure controls have generous hit areas and cancellation paths, and do not depend on color, motion, sound, or haptics alone.
- Keep focus/wayfinding and the escape path clear when a panel or modal appears.
- Test larger text, increased contrast, reduced motion, reduced transparency, light/dark appearances, and real device input.
