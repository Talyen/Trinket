import SwiftUI
import TrinketCore
import TrinketDesignSystem
import XCTest

final class KeywordVisualStyleTests: XCTestCase {
    func testAllKeywordsHaveVisualStyle() {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            XCTAssertNotEqual(style.color, .clear, "\(keyword.rawValue) should have a non-clear color")
            XCTAssertNotEqual(style.glowColor, .clear, "\(keyword.rawValue) should have a glow color")
            XCTAssertNotEqual(style.subtleBackgroundColor, .clear, "\(keyword.rawValue) should have a subtle background color")
            XCTAssertNotEqual(style.borderColor, .clear, "\(keyword.rawValue) should have a border color")
            XCTAssertFalse(style.symbolName.isEmpty, "\(keyword.rawValue) should have a symbol name")
        }
    }
}
