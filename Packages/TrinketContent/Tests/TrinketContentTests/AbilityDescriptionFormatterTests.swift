import Testing
@testable import TrinketContent

struct AbilityDescriptionFormatterTests {
    @Test func representativeAbilityDescriptionsPreserveSemanticFormatting() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.slash) == "Deal 2 Physical damage."
        )
        let description = AbilityDescriptionFormatter.format(.fireArrow)
        try #expect(description.contains("Deal 1 Burn damage"))
        try #expect(!description.contains("applies Burning"))
        try #expect(
            AbilityDescriptionFormatter.format(.fangs) == "Deal 1 Bleed damage. Leech."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.rendingSlash) == "Deal 2 Bleed damage."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.faustianBargain) == "Lose 2 Health. Deal 6 Burn damage."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.cleanse)
                == "Cleanse a status effect and Restore 3 Health."
        )
        try #expect(
            Ability.avatarOfJustice.summary
                == "Gain 4 Block and deal 6 Holy damage each turn for 2 turns."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.manaBerries) == "Restore 2 Mana."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.meteor) == "Deal 6 Burn damage."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.blackjack)
                == "Deal 2 Stun damage or steal 2 Gold."
        )
    }
}
