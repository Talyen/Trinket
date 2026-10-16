import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct AbilityLocalizationTests {
    @Test(arguments: [
        "Take 17% less Holy damage",
        "Physical and Stun damage remove twice as much Block",
        "Purge all buffs from the enemy when you Critically Hit",
        "Purge 3 buffs from the enemy when you Critically Hit",
    ])
    func `saved affix rules remain translated without acquiring new damage bonuses`(description: String) {
        let english = ContentCopy.description(description, locale: Locale(identifier: "en"))
        let expectedQuantities = description.contains("17%") ? ["quantity_1": 17]
            : description.contains("3 buffs") ? ["quantity_1": 3] : [:]
        #expect(english.values == expectedQuantities)
        for language in ["ja", "ko", "de", "zh-Hant", "fr"] {
            let translated = ContentCopy.description(description, locale: Locale(identifier: language))
            #expect(translated.text != english.text)
            #expect(translated.values == expectedQuantities)
            for keyword in [Keyword.physical, .holy] {
                let expected = description.contains(keyword.rawValue) ? 1 : 0
                let actual = translated.spans.count {
                    guard case let .keyword(value) = $0.meaning else { return false }
                    return value == keyword
                }
                #expect(actual == expected)
            }
        }
    }

    @Test func `item nouns stay distinct from attacks with the same English name`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "maul"))
        let item = InventoryItem(id: "localization-maul", baseType: base, rarity: .basic, displayName: base.name, affixes: [])
        let locale = Locale(identifier: "ko")
        #expect(item.localizedDisplayName(locale: locale) == "대형 망치")
        #expect(base.localizedName(locale: locale) == "대형 망치")
        #expect(ContentCopy.localized("Maul", locale: locale) == "후려치기")
        #expect(item.displayName == "Maul")
        #expect(item.baseType.id == "maul")
    }

    @Test func `translated ability rules preserve typed quantities and canonical battle inputs`() throws {
        let ability = try #require(AbilityCatalog.ability(id: "bloodthorn"))
        let original = ability.summary
        let operations = ability.operations
        let english = ability.localizedSummary(locale: Locale(identifier: "en"))
        for language in ["ja", "ko", "de", "zh-Hant", "fr"] {
            let localized = ability.localizedSummary(locale: Locale(identifier: language))
            #expect(localized.values == english.values)
            #expect(!localized.text.contains("<keyword"))
            #expect(localized.spans.contains {
                if case .keyword(.bleed) = $0.meaning {
                    true
                } else {
                    false
                }
            })
            #expect(ability.summary == original)
            #expect(ability.operations == operations)
            #expect(ability.id == "bloodthorn")
        }
    }

    @Test func `native plurals and escaped percent signs render without format artifacts`() {
        let locale = Locale(identifier: "en")
        #expect(EffectPresentation.localizedDescription(for: .drawCards(1), locale: locale).text == "Draw 1 card")
        #expect(EffectPresentation.localizedDescription(for: .drawCards(2), locale: locale).text == "Draw 2 cards")
        let summary = EffectPresentation.localizedDescription(for: .criticalChanceBonus(0.25, 1), locale: locale).text
        #expect(summary.contains("25%"))
        #expect(!summary.contains("%%"))
        #expect(!summary.contains("%1$"))
    }

    @Test func `rolled legacy buff quantities use localized native plurals`() {
        let locale = Locale(identifier: "en")
        let one = ContentCopy.description("Purge a buff when you deal Holy damage", locale: locale)
        let several = ContentCopy.description("Purge 3 buffs when you deal Holy damage", locale: locale)
        #expect(one.text.contains("1 buff"))
        #expect(!one.text.contains("1 buffs"))
        #expect(several.text.contains("3 buffs"))
        #expect(one.values["quantity_1"] == 1)
        #expect(several.values["quantity_1"] == 3)
        for language in ["ja", "ko", "de", "zh-Hant", "fr"] {
            let translated = ContentCopy.description("Purge 3 buffs when you deal Holy damage", locale: Locale(identifier: language))
            #expect(translated.text != several.text)
            #expect(translated.values["quantity_1"] == 3)
        }
    }
}
