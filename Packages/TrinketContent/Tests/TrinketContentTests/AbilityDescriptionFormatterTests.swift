import Testing
import TrinketContent

@Suite
struct AbilityDescriptionFormatterTests {
    @Test func slashFormatsPhysicalDamage() {
        #expect(
            AbilityDescriptionFormatter.format(.slash) == "Deal 1 Physical damage."
        )
    }

    @Test func fireArrowIncludesConditionalBurnRefresh() {
        let description = AbilityDescriptionFormatter.format(.fireArrow)
        #expect(description.contains("Deal 1 Burn damage"))
        #expect(description.contains("applies Burning"))
    }

    @Test func fangsPairsBleedDamageWithStatusPhrase() {
        #expect(
            AbilityDescriptionFormatter.format(.fangs) == "Deal 1 Bleed damage and applies Bleeding."
        )
    }

    @Test func faustianBargainFormatsSelfDamageBeforeOtherClauses() {
        #expect(
            AbilityDescriptionFormatter.format(.faustianBargain) == "Lose 3 Health, deal 6 Physical damage and steal 3 Gold."
        )
    }

    @Test func smellingSaltsFormatsMultipleSupportEffects() {
        #expect(
            AbilityDescriptionFormatter.format(.smellingSalts) == "Cleanse Stunned and Restore 1 Health."
        )
    }

    @Test func manaBerriesRestoreMana() {
        #expect(
            AbilityDescriptionFormatter.format(.manaBerries) == "Deal 1 Burn damage and Restore 1 Mana."
        )
    }

    @Test func meteorIncludesManaCostAndCriticalBonus() {
        let description = AbilityDescriptionFormatter.format(.meteor)
        #expect(description.contains("Costs 5 Mana"))
        #expect(description.contains("deal 6 Burn damage"))
        #expect(description.contains("gain +10% Critical chance"))
    }
}
