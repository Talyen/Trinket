import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct TrinketRarityLabelTests {
    @Test func rarityPresentationMatchesPremiumTreatment() {
        #expect(!TrinketRarityPresentation(rarity: .basic).isPremium)
        #expect(TrinketRarityPresentation(rarity: .astral).isPremium)
    }
}
