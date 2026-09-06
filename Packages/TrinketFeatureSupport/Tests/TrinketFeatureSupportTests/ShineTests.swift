import SwiftUI
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketFeatureSupport

private func baseType(_ id: String) throws -> ItemBaseType {
    try #require(GameContent.itemBaseType(matching: id))
}

private func makeItem(
    baseID: String,
    rarity: Rarity = .basic,
    affixes: [ItemAffix] = [],
    affixPowers: [ItemAffixPower]? = nil,
) throws -> InventoryItem {
    let base = try baseType(baseID)
    return InventoryItem(
        id: base.id,
        baseType: base,
        rarity: rarity,
        displayName: base.name,
        affixes: affixes,
        affixPowers: affixPowers,
    )
}

struct ShineTests {
    @Test func `custom colors compare by value`() {
        let red = Shine.colors([.red])
        let redAgain = Shine.colors([.red])
        let blue = Shine.colors([.blue])
        #expect(red == redAgain)
        #expect(red != blue)
        let burn = Shine.keywords([.burn])
        let burnAgain = Shine.keywords([.burn])
        #expect(burn == burnAgain)
        let none = Shine.none
        let noneAgain = Shine.none
        #expect(none == noneAgain)
        let unique = Shine.unique
        let uniqueAgain = Shine.unique
        #expect(unique == uniqueAgain)
        let corruption = Shine.corruption
        let corruptionAgain = Shine.corruption
        #expect(corruption == corruptionAgain)
        #expect(unique != corruption)
        #expect(none != burn)
    }

    @Test func `name and edge palettes agree`() {
        let burn = Shine.keywords([.burn])
        #expect(burn.textColors == burn.borderColors)
        #expect(burn.textColors == [Keyword.burn.visualStyle.color])
        #expect(Shine.unique.textColors == Shine.unique.borderColors)
        #expect(Shine.unique.textColors == Shine.uniqueBorderColors)
        #expect(Shine.corruption.textColors == Shine.corruption.borderColors)
        #expect(Shine.corruption.textColors == Shine.corruptionBorderColors)
    }

    @Test func `unique items glow unique`() throws {
        let item = try makeItem(baseID: "leather_armor", rarity: .unique)
        #expect(item.displayShine == .unique)
        let gold = Shine.uniqueBorderColors[0]
        #expect(item.displayTextShine.textColors == [gold, gold.opacity(0.55)])
    }

    @Test func `astral glow follows real keywords only`() throws {
        let burnAffix = ItemAffix(
            id: "ember",
            title: "Ember",
            description: "Burn damage",
            keywords: [.burn],
        )
        let burning = try makeItem(baseID: "leather_armor", rarity: .astral, affixes: [burnAffix])
        #expect(burning.displayShine == .keywords([.burn]))

        let plain = try makeItem(baseID: "leather_armor", rarity: .astral)
        #expect(plain.displayShine == .none)
        #expect(plain.astralShineKeywords.isEmpty)
        #expect(plain.displayTextShine == .none)
    }

    @Test func `basic items do not glow`() throws {
        let item = try makeItem(baseID: "leather_armor")
        #expect(item.displayShine == .none)
        #expect(item.displayTextShine == .none)
    }

    @Test func `corrupted affixes glow red outside uniques`() throws {
        let corrupted = ItemAffix(
            id: "tainted",
            title: "Tainted",
            description: "Corrupted power",
            keywords: [.burn],
            isCorrupted: true,
        )
        let item = try makeItem(baseID: "leather_armor", rarity: .astral, affixes: [corrupted])
        #expect(item.affixShine(at: 0, affix: corrupted) == .corruption)

        let unique = try makeItem(baseID: "leather_armor", rarity: .unique, affixes: [corrupted])
        #expect(unique.affixShine(at: 0, affix: corrupted) == unique.displayTextShine)
    }

    @Test(arguments: ["longsword", "brass_censer"])
    func `title palette prefers present affinities and caps keywords`(baseID: String) throws {
        let affix = ItemAffix(
            id: "crowded-shine",
            title: "Crowded",
            description: "Burning, Frozen, Physical, Poison, Bleeding, Burn",
            keywords: [.burn, .freeze, .physical, .poison, .bleed, .dodge],
        )
        let item = try makeItem(baseID: baseID, rarity: .astral, affixes: [affix])
        let selected: [Keyword] = baseID == "longsword" ? [.bleed, .physical, .burn] : [.poison, .bleed, .burn]
        let expected = selected.flatMap { [$0.visualStyle.color, $0.visualStyle.color.opacity(0.55)] }
        #expect(item.displayTextShine.textColors == expected)
        #expect(item.astralShineKeywords.count == 6)
        #expect(Set(item.plasmaKeywords) == affix.keywords)
    }

    @Test func `basic trinket title uses visible secondary keywords`() throws {
        let affix = ItemAffix(
            id: "visible-shine",
            title: "Visible",
            description: "Burning enemies are Frozen. Burn them again.",
            keywords: [.poison],
        )
        let item = try makeItem(baseID: "bone_charm", affixes: [affix])
        let burn = Keyword.burn.visualStyle.color
        let freeze = Keyword.freeze.visualStyle.color
        #expect(item.displayTextShine.textColors == [burn, burn.opacity(0.55), freeze, freeze.opacity(0.55)])
        #expect(item.displayShine == .keywords([.poison]))
    }

    @Test func `titles use resolved descriptions and perfect affixes use description order`() throws {
        let keen = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        let affix = keen.resolved(for: .basic)
        let item = try makeItem(
            baseID: "bone_charm",
            affixes: [affix],
            affixPowers: [ItemAffixPower(
                description: "Frozen Burning Poison Physical Frozen",
                modifiers: [.damageDealt(.physical, 2)],
            )],
        )
        #expect(item.isPerfectAffix(at: 0))
        let titleKeywords: [Keyword] = [.burn, .freeze, .physical]
        let affixKeywords: [Keyword] = [.freeze, .burn, .poison]
        #expect(item.displayTextShine.textColors == titleKeywords.flatMap {
            [$0.visualStyle.color, $0.visualStyle.color.opacity(0.55)]
        })
        #expect(item.affixShine(at: 0, affix: item.displayedAffixes[0]).textColors == affixKeywords.flatMap {
            [$0.visualStyle.color, $0.visualStyle.color.opacity(0.55)]
        })
        let unrolled = try makeItem(baseID: "bone_charm", affixes: [affix])
        #expect(unrolled.affixShine(at: 0, affix: affix) == .none)
    }

    @Test func `single color stops flatten without motion`() {
        let flat = Shine.stops(for: .red, motionEnabled: false)
        #expect(flat.count == 3)
        #expect(flat.allSatisfy { $0.color == .red })

        let animated = Shine.stops(for: .red, motionEnabled: true)
        #expect(animated.count == 6)
        #expect(animated.contains { $0.color != .red })
    }
}

@MainActor
struct KeywordHighlightTests {
    @Test func `keyword terms highlighted deterministically`() {
        let first = KeywordDescriptionText.attributedText(for: "Burn deals damage each round")
        let second = KeywordDescriptionText.attributedText(for: "Burn deals damage each round")
        #expect(first == second)

        let highlighted = first.runs.contains { run in
            run.foregroundColor == Keyword.burn.visualStyle.color
        }
        #expect(highlighted)
    }

    @Test func `plain text carries no highlight`() {
        let attr = KeywordDescriptionText.attributedText(for: "A quiet ordinary sentence")
        #expect(!attr.runs.contains { $0.foregroundColor != nil })
    }
}
