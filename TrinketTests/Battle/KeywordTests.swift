import XCTest
@testable import Trinket

final class KeywordTests: XCTestCase {
    func testAllKeywordsAreCovered() {
        let expected: Set = ["Physical", "Burn", "Stun", "Block", "Armor", "Health", "Gold", "Holy", "Poison", "Bleed", "Leech", "Nature", "Freeze"]
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
        let types: [Keyword] = [.physical, .burn, .poison, .bleed, .holy, .nature]
        for kw in types {
            XCTAssertEqual(kw.category, .damageType, "\(kw.rawValue) should be damageType")
        }
    }

    func testPreventionCategory() {
        let types: [Keyword] = [.stun, .freeze]
        for kw in types {
            XCTAssertEqual(kw.category, .prevention, "\(kw.rawValue) should be prevention")
        }
    }

    func testMitigationCategory() {
        let types: [Keyword] = [.block, .armor]
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

    func testKeywordDescriptionTextRendersWithoutCrash() {
        let sentence = Keyword.allCases.map(\.rawValue).joined(separator: " ")
        let view = KeywordDescriptionText(text: sentence)
        XCTAssertNotNil(view)
    }

    func testCategoryAllCases() {
        let expected: Set = ["Damage Type", "Prevention", "Mitigation", "Restoration", "Resource"]
        let actual = Set(Keyword.Category.allCases.map(\.rawValue))
        XCTAssertEqual(expected, actual)
    }
}
