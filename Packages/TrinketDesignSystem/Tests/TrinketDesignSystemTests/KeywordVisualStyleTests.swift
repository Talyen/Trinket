import Testing
import TrinketCore
import UIKit
@testable import TrinketDesignSystem

struct KeywordVisualStyleTests {
    @Test func `every keyword resolves a visual style with an available symbol`() throws {
        for keyword in Keyword.allCases {
            let style = keyword.visualStyle
            _ = try #require(
                UIImage(systemName: style.icon.symbolName),
                "Missing symbol for \(keyword): \(style.icon.symbolName)",
            )
        }
        for style in [Keyword.VisualStyle.beneficialStatus, .negativeStatus] {
            _ = try #require(UIImage(systemName: style.icon.symbolName))
        }
    }
}
