import SwiftUI
import TrinketCore
import TrinketDesignSystem
import Testing

@Suite
struct KeywordVisualStyleTests {
    @Test func allKeywordsHaveVisualStyle() {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            #expect(style.color != .clear, "\(keyword.rawValue) should have a non-clear color")
            #expect(style.glowColor != .clear, "\(keyword.rawValue) should have a glow color")
            #expect(style.subtleBackgroundColor != .clear, "\(keyword.rawValue) should have a subtle background color")
            #expect(style.borderColor != .clear, "\(keyword.rawValue) should have a border color")
            #expect(!(style.symbolName.isEmpty, "\(keyword.rawValue)) should have a symbol name")
        }
    }
}
