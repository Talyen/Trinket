import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct TrinketRarityLabelTests {
    @Test func basicRarityUsesTheStandardTreatment() {
        let presentation = TrinketRarityPresentation(rarity: .basic)

        #expect(presentation.label == "BASIC")
        #expect(!presentation.isPremium)
    }

    @Test func astralRarityUsesThePremiumTreatment() {
        let presentation = TrinketRarityPresentation(rarity: .astral)

        #expect(presentation.label == "ASTRAL")
        #expect(presentation.isPremium)
    }
}
