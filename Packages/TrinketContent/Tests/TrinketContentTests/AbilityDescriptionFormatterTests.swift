import XCTest
import TrinketContent

final class AbilityDescriptionFormatterTests: XCTestCase {
    func testSlashFormatsPhysicalDamage() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.slash),
            "Deal 1 Physical damage."
        )
    }

    func testFireArrowPairsBurnDamageWithStatusPhrase() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.fireArrow),
            "Deal 1 Burn damage and applies Burning."
        )
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
            "Lose 3 Health, deal 6 Physical damage and gain 3 Gold."
        )
    }

    func testSmellingSaltsFormatsMultipleSupportEffects() {
        XCTAssertEqual(
            AbilityDescriptionFormatter.format(.smellingSalts),
            "Cleanse Stunned and Restore 1 Health."
        )
    }

    func testCatalogGeneratedDescriptionsMatchFormatter() {
        for ability in AbilityCatalog.all {
            XCTAssertEqual(
                ability.generatedDescription,
                AbilityDescriptionFormatter.format(ability),
                "Mismatch for ability \(ability.id)"
            )
        }
    }
}
