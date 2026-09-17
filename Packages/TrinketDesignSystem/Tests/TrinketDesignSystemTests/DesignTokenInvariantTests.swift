import Testing
@testable import TrinketDesignSystem

struct DesignTokenInvariantTests {
    @Test func `shelf spacing shares the shared large step`() {
        #expect(TrinketDesign.Layout.collectionShelfCardSpacing == TrinketDesign.Spacing.large)
    }

    @Test func `opacity tokens stay inside unit range`() {
        for value in [
            TrinketDesign.Opacity.subtle,
            TrinketDesign.Opacity.border,
            TrinketDesign.Opacity.glow,
            TrinketDesign.Opacity.secondary,
            TrinketDesign.Opacity.dragShadow,
            TrinketDesign.Opacity.trailingDamage,
            TrinketDesign.Opacity.battleHealth,
            TrinketDesign.Opacity.placeholderWash,
            TrinketDesign.Opacity.cinematicDim,
            TrinketDesign.Opacity.chipEmphasisStroke,
        ] as [Double] {
            #expect(value > 0 && value <= 1)
        }
    }

    @Test func `grid bounds stay ordered`() {
        #expect(TrinketDesign.Layout.collectionGridMinimum < TrinketDesign.Layout.collectionGridMaximum)
        #expect(TrinketDesign.Layout.partyPickerGridMinimum < TrinketDesign.Layout.partyPickerGridMaximum)
    }

    @Test func `row heights stay positive`() {
        #expect(TrinketDesign.Layout.walletResourceRowMinHeight > 0)
        #expect(TrinketDesign.Layout.mysteryRewardRowMinHeight > 0)
        #expect(TrinketDesign.Layout.cardLabelReservedHeight > 0)
    }
}
