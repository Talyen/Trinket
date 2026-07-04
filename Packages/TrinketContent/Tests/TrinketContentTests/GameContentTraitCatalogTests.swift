import XCTest
@testable import TrinketContent

final class GameContentTraitCatalogTests: XCTestCase {
    func testEveryHeroAndPetReferencesKnownTrait() {
        let traitIDs = Set(GameContent.traits.map(\.id))
        let combatantIDs = GameContent.heroes.map(\.id) + GameContent.pets.map(\.id)

        for combatantID in combatantIDs {
            guard let traitID = GameContent.combatantTraitIDs[combatantID] else {
                XCTFail("Missing trait mapping for combatant \(combatantID)")
                continue
            }
            XCTAssertTrue(
                traitIDs.contains(traitID),
                "Combatant \(combatantID) references unknown trait \(traitID)"
            )
        }
    }

    func testEveryCombatantHasExactlyOneTraitMapping() {
        let combatantIDs = Set(GameContent.heroes.map(\.id) + GameContent.pets.map(\.id))
        XCTAssertEqual(GameContent.combatantTraitIDs.count, combatantIDs.count)
        XCTAssertEqual(Set(GameContent.combatantTraitIDs.keys), combatantIDs)
    }

    func testEveryEnemyHasPositiveAndNegativeTraits() {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            XCTAssertTrue(traitIDs.contains(enemy.positiveTraitID), "\(enemy.name) positive trait")
            XCTAssertTrue(traitIDs.contains(enemy.negativeTraitID), "\(enemy.name) negative trait")
            XCTAssertNotEqual(
                enemy.positiveTraitID,
                enemy.negativeTraitID,
                "\(enemy.name) should not reuse the same trait"
            )
        }
    }

    func testTraitDescriptionsAreNonEmpty() {
        for trait in GameContent.traits {
            XCTAssertFalse(trait.name.isEmpty, "Trait \(trait.id) needs a name")
            XCTAssertFalse(trait.description.isEmpty, "Trait \(trait.id) needs a description")
        }
    }

    func testTraitIDsAreUnique() {
        let ids = GameContent.traits.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
