---
name: apple-design
description: Apple's approach to direct, fluid, accessible interfaces. Use when building or reviewing SwiftUI layout, gesture-driven motion, spring animations, drag/swipe/sheet interactions, translucent materials and depth, typography, feedback, performance, reduced-motion behavior, or Apple-style design foundations.
---

# Apple Design

Use this skill for player-facing interface work involving layout, motion, gestures,
materials, typography, feedback, performance, or accessibility. This file routes the
work; the focused references own the detailed procedure and API examples.

## Trigger Scenarios

- **Activate when**: Authoring, polishing, or redesigning player-facing SwiftUI views, gesture pipelines, or design system components.
- **Do NOT activate when**: Performing localized SwiftUI bug fixes, logic or state refactoring, or non-visual changes.
- **Change Discipline Priority**: Deliver the smallest change that satisfies the request (`AGENTS.md`). Do not add unrequested animations, materials, or visual polish during routine maintenance or bug fixes. Minimal diff discipline overrides design polish when in conflict.

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

Accessibility baseline: [PD-007](../../Product/Decisions.md). Use focused inspection instead of multiplying UI-test variants.

## Core checklist

- Make the primary intent obvious; keep the player in control and confirm only genuinely destructive actions.
- Use native controls and shared DesignSystem primitives before adding custom layout, motion, material, or feedback.
- Keep direct manipulation immediate, continuous, spatially consistent, and interruptible; the focused motion reference owns the mechanics.
- Keep visual, sound, and haptic feedback tied to one committed event, and apply the PD-007 accessibility baseline independently.
- Verify the real screen and input context at normal and reduced-motion settings before handoff.

## Completion check

Before handoff, confirm that the relevant reference was read, DesignSystem primitives
are used, gestures remain cancellable, PD-007 behavior remains intact, and no
unnecessary visual complexity was added.
