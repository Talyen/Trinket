import XCTest
@testable import Trinket

final class ItemAffixCatalogTests: XCTestCase {
    func testAffixIDsAreUnique() {
        let ids = GameContent.itemAffixDefinitions.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEachAffixHasPositiveWeightAndKeywords() {
        for definition in GameContent.itemAffixDefinitions {
            XCTAssertGreaterThan(definition.weight, 0, "\(definition.id) should have positive weight")
            XCTAssertFalse(definition.keywords.isEmpty, "\(definition.id) should declare keywords")
        }
    }

    func testEachAffixDefinesBasicAndAstralPowers() {
        for definition in GameContent.itemAffixDefinitions {
            XCTAssertFalse(definition.basic.description.isEmpty, "\(definition.id) basic description")
            XCTAssertFalse(definition.astral.description.isEmpty, "\(definition.id) astral description")
            XCTAssertFalse(definition.basic.modifiers.isEmpty, "\(definition.id) basic modifiers")
            XCTAssertFalse(definition.astral.modifiers.isEmpty, "\(definition.id) astral modifiers")
        }
    }

    func testEachItemBaseTypeHasEligibleAffixPool() {
        for baseType in GameContent.itemBaseTypes {
            let eligible = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }
            XCTAssertFalse(
                eligible.isEmpty,
                "\(baseType.id) should have at least one eligible affix"
            )
        }
    }
}
