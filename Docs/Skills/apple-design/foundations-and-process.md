# Foundations and process

Use this reference for product-level design critique, restraint, information architecture, wayfinding, interaction/visual integration, and prototype/review practice. Apple’s design foundations serve safety and predictability, understanding, achievement, and joy.

These names come from Apple’s *Principles of Great Design* (WWDC 2026); use them when reasoning about tradeoffs.

## Eight principles

1. **Purpose:** make with intention and decide what not to build. Every feature spends the player’s time, attention, and trust.
2. **Agency:** keep people in control. Offer choices and easy undo; confirm only genuinely destructive, irreversible actions.
3. **Responsibility:** act in the user’s interest. Ask for privacy permissions at the right moment and only for what is needed. Anticipate misuse and harm, especially with AI; add previews, confirmations, or disclaimers when warranted, and cut a feature whose risk outweighs its value.
4. **Familiarity:** build on known metaphors and physics (a trash can means delete). Things that look the same should behave the same and live in the same place (close is consistently top-left on macOS). Break a familiar pattern only when evidence shows it is better, then test it.
5. **Flexibility:** adapt to contexts, devices, expertise, languages, ages, and abilities. An iPhone favors quick touch; a desktop may support deep workflows and precise pointers. Support personalization when no single layout fits everyone.
6. **Simplicity, not minimalism:** strip the unnecessary so the purpose shines. Use plain language, hierarchy, spacing, contrast, and progressive disclosure; adding context can simplify when it clarifies the task. Show the common path first and put advanced options one level deeper.
7. **Craft:** details build trust. Typography, adaptive light/dark color, iconography, responsive animation, spacing, timing, alignment, rotation, and longevity should be deliberate and testable. Jittery scroll, misaligned icons, and layouts that break on rotation read as carelessness.
8. **Delight:** the result of getting the other seven right, not confetti added on top. Choose the desired emotion (calm, confident, excited) and reinforce it consistently.

## Tactical rules

- **Feedback has four jobs:** status, completion, warning, and error. Confirm meaningful actions, expose ongoing status, warn before problems, and validate inline rather than only on submit.
- **Wayfinding:** every screen should answer where the player is, where they can go, what is there, and how to get out. Never trap the player.
- **Grouping and mapping:** proximity implies relationship. Put a control near what it affects and arrange controls to mirror what they change. If a label must explain a control, the mapping may be weak.
- **Specific labels beat generic ones:** name navigation for its contents (for example, “Progress” or “Library”), not vague umbrellas such as “Home.” Specificity creates predictability.

## Process

- Prototype interactively; a working demo is worth a million static designs because playing reveals the interface and sets a concrete bar for implementation.
- Design interaction and visuals together. You should not be able to tell where one ends and the other begins.
- Test with real people in real context. Review motion with fresh eyes at normal speed, slow motion, and frame-by-frame to catch issues hidden at full speed.
