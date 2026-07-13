import Testing
import TrinketContent

struct AbilityDescriptionFormatterTests {
    @Test func representativeAbilityDescriptionsPreserveSemanticFormatting() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.slash) == "Deal 1 Physical damage."
        )
        let description = AbilityDescriptionFormatter.format(.fireArrow)
        try #expect(description.contains("Deal 1 Burn damage"))
        try #expect(!description.contains("applies Burning"))
        try #expect(
            AbilityDescriptionFormatter.format(.fangs) == "Deal 1 Bleed damage."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.faustianBargain) == "Lose 3 Health, deal 6 Physical damage and steal 3 Gold."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.smellingSalts) == "Cleanse Stunned and Restore 1 Health."
        )
        try #expect(
            Ability.avatarOfJustice.summary
                == "Gain 5 Block, Gain 2 Armor and Your attacks become Holy damage and deal +3 for 6 turns."
        )
        try #expect(
            AbilityDescriptionFormatter.format(.manaBerries) == "Deal 1 Burn damage and Restore 1 Mana."
        )
        let meteorDescription = AbilityDescriptionFormatter.format(.meteor)
        try #expect(meteorDescription.contains("Costs 5 Mana"))
        try #expect(meteorDescription.contains("deal 6 Burn damage"))
        try #expect(meteorDescription.contains("gain +10% Critical chance"))
    }
}
