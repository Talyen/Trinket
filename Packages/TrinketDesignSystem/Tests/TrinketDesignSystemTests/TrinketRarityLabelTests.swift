import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct TrinketRarityLabelTests {
    @Test func rarityPresentationMatchesTreatment() {
        let basic = TrinketRarityPresentation(rarity: .basic)
        #expect(basic.label == "BASIC")
        #expect(!basic.isPremium)

        let astral = TrinketRarityPresentation(rarity: .astral)
        #expect(astral.label == "ASTRAL")
        #expect(astral.isPremium)
    }
}
