# TrinketDesignSystem

Shared app chrome — semantic surfaces, typography, keyword visuals, and reusable components. Depends on `TrinketCore` only (no `BattleEngine` or `TrinketContent`).

Use public semantic APIs for product chrome, typography, colors and motion;
feature views must not load package assets directly. Existing accessibility
accommodations and control identifiers remain part of those components.

| Concern | Focused reference |
|---|---|
| Locate the component or source owner | [Components](Documentation/Components.md) |
| Colors, typography, surfaces, keyword identity, game icons | [Visual roles](Documentation/VisualRoles.md) |
| Choose a semantic modifier, button, material or artwork treatment | [Modifiers](Documentation/Modifiers.md) |

Load the matching reference, not the whole inventory. The
[design skill](../../.agents/skills/apple-design/SKILL.md) owns interaction review;
[Architecture](../../Docs/Platform/Architecture.md) owns package boundaries.
