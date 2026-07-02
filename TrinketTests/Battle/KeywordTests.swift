import XCTest
@testable import Trinket

final class KeywordTests: XCTestCase {
    func testAllKeywordsAreCovered() {
        let expected: Set = ["Physical", "Burn", "Stun", "Block", "Armor", "Health", "Gold", "Holy", "Poison", "Bleed", "Leech", "Nature", "Freeze", "Dodge", "Purge"]
        let actual = Set(Keyword.allCases.map(\.rawValue))
        XCTAssertEqual(expected, actual)
    }

    func testAllKeywordsHaveVisualStyle() {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            XCTAssertNotEqual(style.color, .clear, "\(keyword.rawValue) should have a non-clear color")
            XCTAssertFalse(style.symbolName.isEmpty, "\(keyword.rawValue) should have a symbol name")
        }
    }

    func testAllKeywordsHaveRulesText() {
        for keyword in Keyword.allCases {
            XCTAssertFalse(keyword.rulesText.isEmpty, "\(keyword.rawValue) should have rules text")
        }
    }

    func testAllKeywordsHaveCategory() {
        for keyword in Keyword.allCases {
            _ = keyword.category
        }
    }

    func testDamageTypeCategory() {
        let types: [Keyword] = [.physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun]
        for kw in types {
            XCTAssertEqual(kw.category, .damageType, "\(kw.rawValue) should be damageType")
        }
    }

    func testMitigationCategory() {
        let types: [Keyword] = [.block, .armor, .dodge]
        for kw in types {
            XCTAssertEqual(kw.category, .mitigation, "\(kw.rawValue) should be mitigation")
        }
    }

    func testRestorationCategory() {
        let types: [Keyword] = [.health, .leech]
        for kw in types {
            XCTAssertEqual(kw.category, .restoration, "\(kw.rawValue) should be restoration")
        }
    }

    func testResourceCategory() {
        XCTAssertEqual(Keyword.gold.category, .resource)
    }

    func testStatusAliases() {
        XCTAssertEqual(Keyword.freeze.statusAlias, "Frozen")
        XCTAssertEqual(Keyword.stun.statusAlias, "Stunned")
        XCTAssertEqual(Keyword.burn.statusAlias, "Burning")
        XCTAssertEqual(Keyword.poison.statusAlias, "Poisoned")
        XCTAssertEqual(Keyword.bleed.statusAlias, "Bleeding")
    }

    func testKeywordDescriptionTextRendersWithoutCrash() {
        let sentence = Keyword.allCases.map(\.rawValue).joined(separator: " ")
            + " Frozen Stunned Burning Poisoned Bleeding"
        let view = KeywordDescriptionText(text: sentence)
        XCTAssertNotNil(view)
    }

    func testCategoryAllCases() {
        let expected: Set = ["Damage Type", "Mitigation", "Restoration", "Resource"]
        let actual = Set(Keyword.Category.allCases.map(\.rawValue))
        XCTAssertEqual(expected, actual)
    }
}
