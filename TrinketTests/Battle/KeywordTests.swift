import XCTest
@testable import Trinket

final class KeywordTests: XCTestCase {
    func testAllKeywordsHaveVisualStyle() {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            XCTAssertNotEqual(style.color, .clear, "\(keyword.rawValue) should have a non-clear color")
            XCTAssertFalse(style.symbolName.isEmpty, "\(keyword.rawValue) should have a symbol name")
        }
    }

    func testKeywordDescriptionTextRendersWithoutCrash() {
        let sentence = Keyword.allCases.map(\.rawValue).joined(separator: " ")
            + " Frozen Stunned Burning Poisoned Bleeding"
        let view = KeywordDescriptionText(text: sentence)
        XCTAssertNotNil(view)
    }
}
