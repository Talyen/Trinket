import Testing
import TrinketContent

struct AbilityDescriptionFormatterTests {
    @Test func slashFormatsPhysicalDamage() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.slash) == "Deal 1 Physical damage."
        )
    }

    @Test func fireArrowIncludesConditionalBurnRefresh() throws {
        let description = AbilityDescriptionFormatter.format(.fireArrow)
        try #expect(description.contains("Deal 1 Burn damage"))
        try #expect(!description.contains("applies Burning"))
    }

    @Test func fangsPairsBleedDamageWithStatusPhrase() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.fangs) == "Deal 1 Bleed damage."
        )
    }

    @Test func faustianBargainFormatsSelfDamageBeforeOtherClauses() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.faustianBargain) == "Lose 3 Health, deal 6 Physical damage and steal 3 Gold."
        )
    }

    @Test func smellingSaltsFormatsMultipleSupportEffects() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.smellingSalts) == "Cleanse Stunned and Restore 1 Health."
        )
    }

    @Test func avatarOfJusticeDescribesManifestEffects() throws {
        try #expect(
            Ability.avatarOfJustice.summary
                == "Gain 5 Block, Gain 2 Armor and Your attacks become Holy damage and deal +3 for 6 turns."
        )
    }

    @Test func manaBerriesRestoreMana() throws {
        try #expect(
            AbilityDescriptionFormatter.format(.manaBerries) == "Deal 1 Burn damage and Restore 1 Mana."
        )
    }

    @Test func meteorIncludesManaCostAndCriticalBonus() throws {
        let description = AbilityDescriptionFormatter.format(.meteor)
        try #expect(description.contains("Costs 5 Mana"))
        try #expect(description.contains("deal 6 Burn damage"))
        try #expect(description.contains("gain +10% Critical chance"))
    }
}
