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
            AbilityDescriptionFormatter.format(.faustianBargain) == "Lose 3 Health. Draw 3 cards."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.cleanse)
                == "Cleanse a status effect and Restore 2 Health."
        )
        try #expect(
            Ability.avatarOfJustice.summary
                == "Gain Holy damage equal to your Block for 2 turns."
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
