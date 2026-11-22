# Typography

Prefer `.trinketTypography(_:)` and the existing roles in
[visual roles](../../../Packages/TrinketDesignSystem/Documentation/VisualRoles.md#typography),
which already encode the product's text hierarchy.

- Use existing weight, role, spacing, and concise copy before adding a new size
  or role; pick the role that matches the text's job so costs, names, and
  supporting details have clear hierarchy.
- Check long names, prices, and changing values in the available width so
  truncation doesn't hide decision-critical information.
- Tune tracking or leading only when a specific font and size has a visible fit
  or legibility issue.
- Preserve native text scaling within the product's
  [accessibility scope](../../../Docs/Product/Decisions.md).

Platform reference: [Typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography/).

Role-selection guidance includes a modified adaptation of Anthropic's design
principles; see [source and license](foundations-and-process.md#adapted-source).
