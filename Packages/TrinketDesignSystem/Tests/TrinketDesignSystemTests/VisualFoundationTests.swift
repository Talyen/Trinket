import SwiftUI
import Testing
@testable import TrinketDesignSystem

struct VisualFoundationTests {
    @Test func backgroundModeDisplayNamesAreNonEmpty() throws {
        for mode in BackgroundMode.allCases {
            try #expect(!(mode.displayName.isEmpty))
            try #expect(mode.id == mode)
        }
    }

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

    @Test func artworkBlendDestinationsUseSemanticSurfaces() throws {
        try #expect(ArtworkBlendDestination.canvas.color == TrinketDesign.Colors.canvas)
        try #expect(ArtworkBlendDestination.surface.color == TrinketDesign.Colors.surface)
        try #expect(ArtworkBlendDestination.panel.color == TrinketDesign.Colors.panel)
        try #expect(ArtworkBlendDestination.elevated.color == TrinketDesign.Colors.elevated)
    }

    @Test func artworkBlendRecipesPreserveAProtectedCenter() throws {
        try #expect(ArtworkBlendRecipe.perimeterShoulderLocation < ArtworkBlendRecipe.perimeterInnerLocation)
        try #expect(ArtworkBlendRecipe.perimeterInnerLocation < 0.5)
        try #expect(ArtworkBlendRecipe.bottomClearLocation < ArtworkBlendRecipe.bottomShoulderLocation)
        try #expect(ArtworkBlendRecipe.bottomShoulderLocation < ArtworkBlendRecipe.bottomNearEdgeLocation)
        try #expect(ArtworkBlendRecipe.bottomNearEdgeLocation < 1)
    }
}
