import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct ItemCorruptionTests {
    @Test func `never produces zero affix items`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 1)
        var rng = SeededRandomNumberGenerator(seed: 42)
        for _ in 0 ..< 40 {
            let result = try #require(ItemCorruption.corrupt(item, using: &rng))
            #expect(!result.item.affixes.isEmpty)
            #expect(result.item.affixes.count >= item.affixes.count)
            #expect(result.item.isCorrupted)
            #expect(result.item.affixPowers?.count == result.item.affixes.count)
            #expect(result.item.affixes.filter(\.isCorrupted).count == 1)
            #expect(result.originalItem == item)
        }
    }

    @Test func `added affix becomes the corruption mark`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 5)

        let result = ItemCorruption.apply(kinds: [.addAffix], to: item, using: &rng)

        let originalIDs = Set(item.affixes.map(\.id))
        let marked = result.item.affixes.filter(\.isCorrupted)
        #expect(result.item.affixes.count == 3)
        #expect(marked.count == 1)
        #expect(marked.allSatisfy { !originalIDs.contains($0.id) })
    }

    @Test func `replaced affix becomes the corruption mark`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 11)

        let result = ItemCorruption.apply(kinds: [.replaceAffix], to: item, using: &rng)

        let originalIDs = Set(item.affixes.map(\.id))
        let marked = result.item.affixes.filter(\.isCorrupted)
        #expect(result.item.affixes.count == 2)
        #expect(marked.count == 1)
        #expect(marked.allSatisfy { !originalIDs.contains($0.id) })
    }

    @Test func `powerless roll still marks A survivor`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 13)

        let result = ItemCorruption.apply(kinds: [.upgradeRarity], to: item, using: &rng)

        #expect(result.item.rarity == .astral)
        #expect(result.item.affixes.count == 2)
        #expect(result.item.affixes.filter(\.isCorrupted).count == 1)
    }

    @Test func `altar eligibility matrix`() throws {
        let plain = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        #expect(ItemCorruption.isEligibleTarget(plain))

        let trinket = try #require(GameContent.trinketItems.first)
        #expect(!ItemCorruption.isEligibleTarget(trinket))

        let legacyFlagged = InventoryItem(
            id: plain.id,
            baseType: plain.baseType,
            rarity: plain.rarity,
            displayName: plain.displayName,
            affixes: plain.affixes,
            isCorrupted: true,
        )
        #expect(!ItemCorruption.isEligibleTarget(legacyFlagged))

        let markedOnly = withMarkedFirstAffix(plain)
        #expect(markedOnly.hasCorruptedAffix)
        #expect(!markedOnly.isCorrupted)
        #expect(!ItemCorruption.isEligibleTarget(markedOnly))
    }

    @Test func `three or more affixes force astral`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let result = ItemCorruption.apply(
            kinds: [.addAffix],
            to: item,
            using: &rng,
        )
        #expect(result.item.affixes.count == 3)
        #expect(result.item.rarity == .astral)
        #expect(result.effects.contains(.upgradedRarity))
    }

    @Test func `already corrupted items rejected`() throws {
        var item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        item = InventoryItem(
            id: item.id,
            templateID: item.templateID,
            baseType: item.baseType,
            rarity: item.rarity,
            displayName: item.displayName,
            affixes: item.affixes,
            isCorrupted: true,
            affixPowers: item.affixes.compactMap {
                GameContent.itemAffixDefinition(matching: $0.id)?.power(for: item.rarity)
            },
        )
        var save = PlayerSave.testSeed
        save.inventory.items = [item]
        var rng = SeededRandomNumberGenerator(seed: 1)
        let result = ItemCorruptionApplier.corrupt(itemID: item.id, save: &save, using: &rng)
        #expect(result == .alreadyCorrupted)
    }

    @Test func `trinkets cannot be corrupted`() throws {
        let trinket = try #require(GameContent.trinketItems.first)
        var save = PlayerSave.fresh
        save.inventory.items = [trinket]
        var rng = SeededRandomNumberGenerator(seed: 1)

        let result = ItemCorruptionApplier.corrupt(itemID: trinket.id, save: &save, using: &rng)

        #expect(result == .ineligible)
        #expect(save.inventory.items == [trinket])
    }

    @Test @MainActor func `corruption persists across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let item = try makeItem(baseID: "sapphire_ring", rarity: .basic, affixCount: 2, id: "corrupt-ring")
        try store.performBatchMutation { save in
            save.inventory.items = [item]
        }

        var applied: ItemCorruptionResult?
        try store.performBatchMutation { save in
            var rng = SeededRandomNumberGenerator(seed: 99)
            if case let .success(result) = ItemCorruptionApplier.corrupt(
                itemID: item.id,
                save: &save,
                using: &rng,
            ) {
                applied = result
                ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
            }
        }

        let result = try #require(applied)
        #expect(result.item.isCorrupted)
        #expect(result.item.affixes.filter(\.isCorrupted).count == 1)
        #expect(store.currentSave.corruptionAltarCooldownRemaining == 6)

        let reloaded = try context.makeSaveStore()
        let reloadedItem = try #require(reloaded.currentSave.inventory.items.first { $0.id == item.id })
        #expect(reloadedItem.isCorrupted)
        #expect(reloadedItem.hasCorruptedAffix)
        #expect(reloadedItem.affixes.filter(\.isCorrupted).count == 1)
        #expect(reloadedItem.affixPowers?.count == reloadedItem.affixes.count)
        #expect(reloaded.currentSave.corruptionAltarCooldownRemaining == 6)

        #expect(!ItemCorruption.isEligibleTarget(reloadedItem))
    }

    @Test func `cooldown decrements on non altar mystery`() {
        var save = PlayerSave.testSeed
        save.corruptionAltarCooldownRemaining = 3
        ItemCorruptionApplier.noteMysteryCompleted(save: &save)
        #expect(save.corruptionAltarCooldownRemaining == 2)
        ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
        #expect(save.corruptionAltarCooldownRemaining == 6)
    }

    @Test func `bump down does not zero sole numeric`() throws {
        let keen = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        let base = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let affix = keen.resolved(for: .basic)
        let item = InventoryItem(
            id: "bump-sword",
            baseType: base,
            rarity: .basic,
            displayName: base.name,
            affixes: [affix],
        )
        var rng = SeededRandomNumberGenerator(seed: 3)
        let result = ItemCorruption.apply(
            kinds: [.bumpDown],
            to: item,
            using: &rng,
        )
        #expect(result.item.isCorrupted)
        #expect(!result.item.affixes.isEmpty)
    }

    @Test func `bump changes only the selected standalone description value`() throws {
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        var powers = [executioners.basic]
        var rng = SeededRandomNumberGenerator(seed: 0)

        let title = ItemAffixPower.applyBump(
            direction: .up,
            to: &powers,
            affixIDs: [executioners.id],
            using: &rng,
        )?.title

        #expect(title == executioners.title)
        #expect(powers[0].triggers == CombatTraitTriggers(
            damage: DamageTriggers(
                damageBelowHealthPercentThreshold: 0.30,
                damageBelowHealthPercentBonus: 4,
            ),
        ))
        #expect(powers[0].description == "Deal 4 additional damage if the enemy is below 30% Health.")
    }

    @Test func `minimum integer and percent values cannot bump down`() {
        var powers = [
            ItemAffixPower(description: "Gain 1 Strength.", modifiers: [.strength(1)]),
            ItemAffixPower(description: "Gain 1% more Gold.", modifiers: [.goldGainedPercent(0.01)]),
        ]
        let original = powers
        var rng = SeededRandomNumberGenerator(seed: 0)

        let title = ItemAffixPower.applyBump(
            direction: .down,
            to: &powers,
            affixIDs: ["strength", "gold"],
            using: &rng,
        )?.title

        #expect(title == nil)
        #expect(powers == original)
    }

    @Test func `bump modifier up and down updates both power and description`() {
        var powers = [
            ItemAffixPower(description: "Gain 5 Strength.", modifiers: [.strength(5)]),
            ItemAffixPower(description: "Gain 10% more Gold.", modifiers: [.goldGainedPercent(0.10)]),
        ]
        var rng = SeededRandomNumberGenerator(seed: 12)

        let titleUp = ItemAffixPower.applyBump(
            direction: .up,
            to: &powers,
            affixIDs: ["strength", "gold"],
            using: &rng,
        )?.title
        #expect(titleUp != nil)

        let titleDown = ItemAffixPower.applyBump(
            direction: .down,
            to: &powers,
            affixIDs: ["strength", "gold"],
            using: &rng,
        )?.title
        #expect(titleDown != nil)
    }

    @Test func `bump does not replace percentage token when integer matches`() {
        var powers = [
            ItemAffixPower(
                description: "Gain 20 Strength when below 20% Health.",
                modifiers: [.strength(20)],
            ),
        ]
        var rng = SeededRandomNumberGenerator(seed: 0)

        let title = ItemAffixPower.applyBump(
            direction: .up,
            to: &powers,
            affixIDs: ["strength"],
            using: &rng,
        )?.title

        #expect(title != nil)
        #expect(powers[0].modifiers == [.strength(21)])
        #expect(powers[0].description == "Gain 21 Strength when below 20% Health.")
    }

    @Test func `bump trigger target increments and updates description`() {
        var powers = [
            ItemAffixPower(
                description: "Apply 2 Poison when target Bleeds.",
                modifiers: [],
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(
                        onBleedApplyPoison: 2,
                    ),
                ),
            ),
        ]
        var rng = SeededRandomNumberGenerator(seed: 0)

        let title = ItemAffixPower.applyBump(
            direction: .up,
            to: &powers,
            affixIDs: ["bleed_poison"],
            using: &rng,
        )?.title

        #expect(title == "bleed_poison")
        #expect(powers[0].triggers.onBleedApplyPoison == 3)
        #expect(powers[0].description == "Apply 3 Poison when target Bleeds.")
    }

    @Test func `bump applies integer and percent triggers correctly`() {
        var intPowers = [
            ItemAffixPower(
                description: "Gain 5 Block when broken.",
                modifiers: [],
                triggers: CombatTraitTriggers(block: BlockTriggers(blockBrokenBlockFlat: 5)),
            ),
        ]
        var rng = SeededRandomNumberGenerator(seed: 1)
        _ = ItemAffixPower.applyBump(direction: .up, to: &intPowers, affixIDs: ["test_block"], using: &rng)
        #expect(intPowers[0].triggers.blockBrokenBlockFlat == 6)
        #expect(intPowers[0].description == "Gain 6 Block when broken.")

        var pctPowers = [
            ItemAffixPower(
                description: "Gain 25% Thorns.",
                modifiers: [],
                triggers: CombatTraitTriggers(mitigation: MitigationTriggers(thornsPercent: 0.25)),
            ),
        ]
        _ = ItemAffixPower.applyBump(direction: .up, to: &pctPowers, affixIDs: ["test_thorns"], using: &rng)
        #expect(abs(pctPowers[0].triggers.thornsPercent - 0.26) < 0.001)
        #expect(pctPowers[0].description == "Gain 26% Thorns.")
    }
}

private func makeItem(
    baseID: String,
    rarity: Rarity,
    affixCount: Int = 1,
    id: String = "test-item",
) throws -> InventoryItem {
    let base = try #require(GameContent.itemBaseTypes.first { $0.id == baseID })
    let pool = GameContent.itemAffixDefinitions.filter { $0.slot == base.slot }
    let definitions = Array(pool.prefix(affixCount))
    try #require(definitions.count == affixCount)
    return InventoryItem(
        id: id,
        baseType: base,
        rarity: rarity,
        displayName: base.name,
        affixes: definitions.map { $0.resolved(for: rarity) },
    )
}

private func withMarkedFirstAffix(_ item: InventoryItem) -> InventoryItem {
    InventoryItem(
        id: item.id,
        templateID: item.templateID,
        baseType: item.baseType,
        rarity: item.rarity,
        displayName: item.displayName,
        affixes: item.affixes.enumerated().map { index, affix in
            ItemAffix(
                id: affix.id,
                title: affix.title,
                description: affix.description,
                keywords: affix.keywords,
                isCorrupted: index == 0,
            )
        },
        isCorrupted: false,
        affixPowers: item.affixPowers,
    )
}
