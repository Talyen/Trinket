---
name: apple-design
description: Apple's approach to direct, fluid, accessible interfaces. Use when building or reviewing SwiftUI layout, gesture-driven motion, spring animations, drag/swipe/sheet interactions, translucent materials and depth, typography, feedback, performance, reduced-motion behavior, or Apple-style design foundations.
---

# Apple Design

Use this skill for player-facing interface work involving layout, motion, gestures,
materials, typography, feedback, performance, or accessibility. It distills Apple’s
design guidance into SwiftUI and TrinketDesignSystem practices. Read this checklist,
then each focused reference that matches the work.

## Route by work

| Work | Required reference |
| --- | --- |
| Drag, swipe, tap, sheet, spring, momentum, interruption, or spatial transitions | [Motion and gestures](motion-and-gestures.md) |
| Glass, blur, translucency, scrims, hierarchy, depth, or floating chrome | [Materials and depth](materials-and-depth.md) |
| Font choice, Dynamic Type, optical sizing, tracking, leading, or hierarchy | [Typography](typography.md) |
| Reduced motion/transparency/contrast, vestibular safety, or inclusive interaction | [Accessibility](accessibility.md) |
| Frame smoothness, compositor work, haptics, sound, or feedback timing | [Performance and feedback](performance-and-feedback.md) |
| Product-level critique, wayfinding, restraint, or design process | [Foundations and process](foundations-and-process.md) |

For Trinket’s iOS 26+ screens, use first-party SwiftUI APIs and
`TrinketDesignSystem` for reusable chrome, motion, and product colors.

## Trinket product override

PD-007 defines a practical native baseline: preserve native semantics, label custom
interactive controls, support Dynamic Type on reading/navigation surfaces, handle
reduced motion/transparency centrally, and never rely on color, sound, or motion alone
for essential state. Use focused inspection instead of multiplying UI-test variants.

## Core checklist

- **Purpose and agency:** Make the primary intent obvious, keep the player in control, preserve undo/forgiveness, and ask for confirmation only when an action is genuinely destructive and irreversible.
- **Immediate, continuous response:** Acknowledge press-down immediately and keep feedback 1:1 throughout a drag, slider, or drawer. Remove avoidable latency from the input path.
- **Physical, interruptible motion:** Start from the live presentation value, carry release velocity into the next spring, project momentum before choosing a snap point, and let a moving element be grabbed and redirected at any time.
- **Spatial consistency:** Enter and exit along the same path, anchor overlays to their source, hint at the destination during travel, and soften boundaries with progressive resistance instead of hard stops.
- **Clear hierarchy:** Use material weight, spacing, contrast, type, grouping, and mapping to show what matters. Every element and every timing value should have a defensible purpose.
- **Synchronized feedback:** Visual, sound, and haptic feedback should be caused by the same event, fire together, and earn their place.
- **Inclusive by default:** Apply the PD-007 baseline through shared components and native controls.
- **Verify in context:** Prototype the interaction, inspect motion at normal and slow speed, and test the real screen and input context with real people when possible.

## Completion check

Before handing off, confirm that the relevant references were read, the implementation
uses project design-system primitives, gestures remain cancellable and interruptible,
native control behavior and the PD-007 baseline remain intact, and no unnecessary
animation, material, feedback, or complexity was added.
