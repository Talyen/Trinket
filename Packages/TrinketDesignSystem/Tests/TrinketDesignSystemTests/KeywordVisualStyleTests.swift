import SwiftUI
import Testing
import TrinketCore
import TrinketDesignSystem

struct KeywordVisualStyleTests {
    @Test func allKeywordsHaveVisualStyle() throws {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            try #expect(style.color != .clear, "\(keyword.rawValue) should have a non-clear color")
            try #expect(style.glowColor != .clear, "\(keyword.rawValue) should have a glow color")
            try #expect(style.subtleBackgroundColor != .clear, "\(keyword.rawValue) should have a subtle background color")
            try #expect(style.borderColor != .clear, "\(keyword.rawValue) should have a border color")
            try #expect(!style.symbolName.isEmpty, "\(keyword.rawValue)) should have a symbol name")
        }
    }

    @Test func genericCombatStatusesUseEstablishedSemanticStyles() {
        #expect(Keyword.VisualStyle.beneficialStatus.symbolName == "arrowshape.up.fill")
        #expect(Keyword.VisualStyle.beneficialStatus.color == TrinketDesign.Colors.success)
        #expect(Keyword.VisualStyle.negativeStatus.symbolName == "arrowshape.down.fill")
        #expect(Keyword.VisualStyle.negativeStatus.color == TrinketDesign.Colors.destructive)
    }
}
