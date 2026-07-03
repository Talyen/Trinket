import SwiftUI
import TrinketCore
import TrinketDesignSystem
import XCTest

final class KeywordVisualStyleTests: XCTestCase {
    func testAllKeywordsHaveVisualStyle() {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            XCTAssertNotEqual(style.color, .clear, "\(keyword.rawValue) should have a non-clear color")
            XCTAssertFalse(style.symbolName.isEmpty, "\(keyword.rawValue) should have a symbol name")
        }
    }
}
