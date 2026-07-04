import TrinketCore
import XCTest

final class KeywordCoreTests: XCTestCase {
    func testAllKeywordsAreCovered() {
        let expected: Set = [
            "Physical", "Burn", "Stun", "Block", "Armor", "Health", "Gold", "Holy", "Poison",
            "Bleed", "Leech", "Nature", "Freeze", "Dodge", "Purge", "Mana", "Death's Door",
        ]
        let actual = Set(Keyword.allCases.map(\.rawValue))
        XCTAssertEqual(expected, actual)
    }

    func testAllKeywordsHaveRulesText() {
        for keyword in Keyword.allCases {
            XCTAssertFalse(keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
        }
    }

    func testAllKeywordsHaveCategory() {
        for keyword in Keyword.allCases {
            XCTAssertNotNil(keyword.category.rawValue)
        }
    }

    func testDamageTypeCategory() {
        let types: [Keyword] = [.physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun]
        for kw in types {
            XCTAssertEqual(kw.category, .damageType, "\(kw.rawValue) should be damageType")
        }
    }

    func testMitigationCategory() {
        let types: [Keyword] = [.block, .armor, .dodge, .purge]
        for kw in types {
            XCTAssertEqual(kw.category, .mitigation, "\(kw.rawValue) should be mitigation")
        }
    }

    func testRestorationCategory() {
        let types: [Keyword] = [.health, .leech, .deathsDoor]
        for kw in types {
            XCTAssertEqual(kw.category, .restoration, "\(kw.rawValue) should be restoration")
        }
    }

    func testResourceCategory() {
        let types: [Keyword] = [.gold, .mana]
        for kw in types {
            XCTAssertEqual(kw.category, .resource, "\(kw.rawValue) should be resource")
        }
    }

    func testStatusAliases() {
        XCTAssertEqual(Keyword.freeze.statusAlias, "Frozen")
        XCTAssertEqual(Keyword.stun.statusAlias, "Stunned")
        XCTAssertEqual(Keyword.burn.statusAlias, "Burning")
        XCTAssertEqual(Keyword.poison.statusAlias, "Poisoned")
        XCTAssertEqual(Keyword.bleed.statusAlias, "Bleeding")
    }

    func testCategoryAllCases() {
        let expected: Set = ["Damage Type", "Mitigation", "Restoration", "Resource"]
        let actual = Set(Keyword.Category.allCases.map(\.rawValue))
        XCTAssertEqual(expected, actual)
    }
}
