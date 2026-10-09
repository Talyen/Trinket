# Typography

Use `.trinketTypography(_:)` and the existing roles in
[visual roles](../../../Packages/TrinketDesignSystem/Documentation/VisualRoles.md#typography).
Inspect that implementation before changing font, tracking, or line spacing;
role defaults already encode the product's text hierarchy.

- Use weight, role, spacing, and concise copy to distinguish information before
  introducing a new size or role. Choose the role for the text's job in the
  player's decision; give costs, names, and supporting detail a deliberate
  hierarchy rather than styling every label as a headline.
- Check real labels, long names, prices, and changing values in the available width.
  Truncation must not hide the information needed to make the choice.
- Tune tracking or leading only for a visible problem with the selected font and
  size. Do not apply a universal rule that every heading needs negative tracking
  or every small label needs positive tracking.
- Preserve native text scaling within the product's
  [accessibility scope](../../../Docs/Product/Decisions.md); do not introduce
  setting-specific layout branches as incidental typography work.

Platform reference: [Typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography/).

Role-selection guidance includes a modified adaptation of Anthropic's design
principles; see [source and license](foundations-and-process.md#adapted-source).
