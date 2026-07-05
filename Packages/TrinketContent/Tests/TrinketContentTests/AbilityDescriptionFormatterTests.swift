import XCTest
import TrinketContent

final class AbilityDescriptionFormatterTests: XCTestCase {
    func testSlashFormatsPhysicalDamage() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.slash),
            "Deal 1 Physical damage."
        )
    }

    func testFireArrowIncludesConditionalBurnRefresh() {
        let description = AbilityDescriptionFormatter.format(.fireArrow)
        XCTAssertTrue(description.contains("Deal 1 Burn damage"))
        XCTAssertTrue(description.contains("applies Burning"))
    }

    func testFangsPairsBleedDamageWithStatusPhrase() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.fangs),
            "Deal 1 Bleed damage and applies Bleeding."
        )
    }

    func testFaustianBargainFormatsSelfDamageBeforeOtherClauses() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.faustianBargain),
            "Lose 3 Health, deal 6 Physical damage and steal 3 Gold."
        )
    }

    func testSmellingSaltsFormatsMultipleSupportEffects() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.smellingSalts),
            "Cleanse Stunned and Restore 1 Health."
        )
    }

    func testManaBerriesRestoreMana() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.manaBerries),
            "Deal 1 Burn damage and Restore 1 Mana."
        )
    }

    func testMeteorIncludesManaCostAndCriticalBonus() {
        let description = AbilityDescriptionFormatter.format(.meteor)
        XCTAssertTrue(description.contains("Costs 5 Mana"))
        XCTAssertTrue(description.contains("deal 6 Burn damage"))
        XCTAssertTrue(description.contains("gain +10% Critical chance"))
    }
}
