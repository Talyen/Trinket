import SwiftUI
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketFeatureSupport

@MainActor
struct KeywordHighlightTests {
    @Test func `changed affixes on the same item retain their current shine colors`() {
        let base = ItemBaseType(id: "shine-fixture", name: "Sword", slot: .weapon, weaponKind: .oneHanded, keywordAffinities: [])
        func item(description: String) -> InventoryItem {
            InventoryItem(
                id: "same-item", baseType: base, rarity: .astral, displayName: "Sword",
                affixes: [ItemAffix(id: "shine-fixture", title: "Trait", description: description, keywords: [])],
            )
        }
        let burning = item(description: "Apply Burn.")
        let poisoned = item(description: "Apply Poison.")
        #expect(burning.displayTextShine == .itemText(colors: [Keyword.burn.visualStyle.color]))
        #expect(poisoned.displayTextShine == .itemText(colors: [Keyword.poison.visualStyle.color]))
        #expect(item(description: "An ordinary trait.").displayTextShine == .none)
        #expect(burning.displayTextShine == .itemText(colors: [Keyword.burn.visualStyle.color]))
    }

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
