import Foundation
import SwiftUI
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketFeatureSupport

@MainActor
struct KeywordHighlightTests {
    @Test(arguments: [
        ("Take 10% less Holy damage", "Deal 2 bonus Holy damage. Take 25% less Holy damage"),
        (
            "Purge a buff from the enemy when you Critically Hit",
            "Deal 2 bonus Physical damage. Purge all buffs from the enemy when you Critically Hit",
        ),
    ])
    func `reworked affixes do not compare unrelated saved stats`(before: String, after: String) {
        let locale = Locale(identifier: "en")
        let original = ContentCopy.description(before, locale: locale)
        let updated = ContentCopy.description(after, locale: locale)
        #expect(KeywordDescriptionText.attributedText(for: updated, comparison: original)
            == KeywordDescriptionText.attributedText(for: updated))
    }

    @Test func `matching affix rules still show numerical upgrade colors`() {
        let locale = Locale(identifier: "en")
        let original = ContentCopy.description("Deal 1 bonus Holy damage. Take 10% less Holy damage", locale: locale)
        let updated = ContentCopy.description("Deal 2 bonus Holy damage. Take 25% less Holy damage", locale: locale)
        #expect(KeywordDescriptionText.attributedText(for: updated, comparison: original)
            != KeywordDescriptionText.attributedText(for: updated))
    }

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
    }

    @Test func `keyword terms carry their matching color`() {
        let text = KeywordDescriptionText.attributedText(for: LocalizedGameText(markedText: "<keyword id=\"burn\">炎上</keyword>のダメージ"))
        let highlighted = text.runs.contains { run in
            run.foregroundColor == Keyword.burn.visualStyle.color
        }
        #expect(highlighted)
    }

    @Test func `upgrade colors match quantity identities rather than translated number positions`() {
        let previous = LocalizedGameText(
            markedText: "<value id=\"damage\">3</value> / <value id=\"turns\">2</value>",
            values: ["damage": 3, "turns": 2],
        )
        let upgraded = LocalizedGameText(
            markedText: "<value id=\"turns\">2</value>回、<value id=\"damage\">5</value>",
            values: ["damage": 5, "turns": 2],
        )
        let text = KeywordDescriptionText.attributedText(for: upgraded, comparison: previous)
        let colored = text.runs.filter { $0.foregroundColor != nil }.map { String(text[$0.range].characters) }
        #expect(colored == ["5"])
    }

    @Test func `plain text carries no highlight`() {
        let attr = KeywordDescriptionText.attributedText(for: "A quiet ordinary sentence")
        #expect(!attr.runs.contains { $0.foregroundColor != nil })
    }
}
