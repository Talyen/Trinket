import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct VisualFoundationTests {
    @Test func typographyRolesProvideFonts() throws {
        try #expect(TypographyRole.button.font != TypographyRole.body.font)
        try #expect(TypographyRole.statValue.font != TypographyRole.tooltip.font)
        try #expect(TypographyRole.eyebrow.font != TypographyRole.caption.font)
        try #expect(TypographyRole.screenDisplay.font != TypographyRole.screenTitle.font)
        try #expect(TypographyRole.sectionDisplay.font != TypographyRole.sectionTitle.font)
        try #expect(TypographyRole.rowTitle.font != TypographyRole.sectionTitle.font)
        try #expect(TypographyRole.rowTitle.font != TypographyRole.cardTitle.font)
        try #expect(TypographyRole.cardLabel.font != TypographyRole.secondaryBody.font)
        try #expect(TypographyRole.footnote.font != TypographyRole.caption.font)
    }

    @Test func artworkBlendRecipePreservesAProtectedCenter() throws {
        try #expect(ArtworkBlendRecipe.shoulderInset < ArtworkBlendRecipe.clearInset)
        try #expect(ArtworkBlendRecipe.clearInset < 0.5)
        try #expect(ArtworkBlendRecipe.shoulderOpacity < ArtworkBlendRecipe.edgeOpacity)
    }
}
