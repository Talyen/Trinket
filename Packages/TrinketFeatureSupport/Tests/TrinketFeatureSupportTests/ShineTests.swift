import SwiftUI
import Testing
import TrinketCore
@testable import TrinketFeatureSupport

@MainActor
struct KeywordHighlightTests {
    @Test func `keyword terms carry their matching color`() {
        let text = KeywordDescriptionText.attributedText(for: "Burn deals damage each round")
        let highlighted = text.runs.contains { run in
            run.foregroundColor == Keyword.burn.visualStyle.color
        }
        #expect(highlighted)
    }

    @Test func `plain text carries no highlight`() {
        let attr = KeywordDescriptionText.attributedText(for: "A quiet ordinary sentence")
        #expect(!attr.runs.contains { $0.foregroundColor != nil })
    }
}
