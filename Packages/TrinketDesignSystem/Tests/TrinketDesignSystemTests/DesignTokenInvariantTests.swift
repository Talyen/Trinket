import Testing
@testable import TrinketDesignSystem

struct DesignTokenInvariantTests {
    @Test func `shelf spacing shares the shared large step`() {
        #expect(TrinketDesign.Layout.collectionShelfCardSpacing == TrinketDesign.Spacing.large)
    }

    @Test(arguments: [
        ("subtle", TrinketDesign.Opacity.subtle),
        ("border", TrinketDesign.Opacity.border),
        ("glow", TrinketDesign.Opacity.glow),
        ("secondary", TrinketDesign.Opacity.secondary),
        ("dragShadow", TrinketDesign.Opacity.dragShadow),
        ("trailingDamage", TrinketDesign.Opacity.trailingDamage),
        ("battleHealth", TrinketDesign.Opacity.battleHealth),
        ("placeholderWash", TrinketDesign.Opacity.placeholderWash),
        ("cinematicDim", TrinketDesign.Opacity.cinematicDim),
        ("chipEmphasisStroke", TrinketDesign.Opacity.chipEmphasisStroke),
        ("shineDim", TrinketDesign.Opacity.shineDim),
    ])
    func `opacity tokens stay inside unit range`(name: String, value: Double) {
        #expect(value > 0 && value <= 1, "\(name) out of unit range")
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
