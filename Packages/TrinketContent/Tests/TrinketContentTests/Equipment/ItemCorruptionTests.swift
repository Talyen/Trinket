import Testing
import TrinketCore
@testable import TrinketContent

struct ItemCorruptionTests {
    @Test func `structural corruption preserves surviving rolls`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "longsword"))
        var rng = SeededRandomNumberGenerator(seed: 1772)
        let item = ItemGenerator().generate(
            id: "rolled-sword", baseType: base, rarity: .astral,
            fixedAffixCount: 4, using: &rng,
        )
        let originalPowers = try #require(item.affixPowers)
        let catalogPowers = item.affixes.compactMap {
            GameContent.itemAffixDefinition(matching: $0.id)?.power(for: item.rarity)
        }
        #expect(originalPowers != catalogPowers)
        for kind in [CorruptionEffectKind.addAffix, .replaceAffix] {
            let result = try #require(ItemCorruption.apply(kinds: [kind], to: item, using: &rng))
            _ = try #require(result.item.affixPowers)
            for (index, affix) in result.item.affixes.enumerated() {
                if let originalIndex = item.affixes.firstIndex(where: { $0.id == affix.id }) {
                    #expect(result.item.resolvedPower(at: index) == item.resolvedPower(at: originalIndex))
                }
            }
        }
    }

    @Test func `effect rolls follow authored order for fixed seed`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 123)

        let kinds = ItemCorruption.rollEffectKinds(for: item, using: &rng)

        #expect(kinds == [.replaceAffix, .upgradeRarity])
    }

    @Test func `empty effect roll falls back through authored order`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = MaximumRandomNumberGenerator()

        let kinds = ItemCorruption.rollEffectKinds(for: item, using: &rng)

        #expect(kinds == [.upgradeRarity])
    }

    @Test func `structural effects preserve base item eligibility`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)

        for kind in [CorruptionEffectKind.addAffix, .replaceAffix] {
            for seed in UInt64(1) ... 64 {
                var rng = SeededRandomNumberGenerator(seed: seed)
                let result = try #require(ItemCorruption.apply(kinds: [kind], to: item, using: &rng))
                let expectedCount = kind == .addAffix ? item.affixes.count + 1 : item.affixes.count

                #expect(result.item.affixes.count == expectedCount)
                #expect(Set(result.item.affixes.map(\.id)).count == result.item.affixes.count)
                #expect(result.item.affixes.count(where: \.isCorrupted) == 1)
                for affix in result.item.affixes {
                    let definition = try #require(GameContent.itemAffixDefinition(matching: affix.id))
                    #expect(definition.slot == item.baseType.slot)
                    #expect(!definition.keywords.isDisjoint(with: item.baseType.keywordAffinities))
                }
            }
        }
    }

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

        let result = try #require(ItemCorruption.apply(kinds: [.addAffix], to: item, using: &rng))

        let originalIDs = Set(item.affixes.map(\.id))
        let marked = result.item.affixes.filter(\.isCorrupted)
        #expect(result.item.affixes.count == 3)
        #expect(marked.count == 1)
        #expect(marked.allSatisfy { !originalIDs.contains($0.id) })
    }

    @Test func `replaced affix becomes the corruption mark`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 11)

        let result = try #require(ItemCorruption.apply(kinds: [.replaceAffix], to: item, using: &rng))

        let originalIDs = Set(item.affixes.map(\.id))
        let marked = result.item.affixes.filter(\.isCorrupted)
        #expect(result.item.affixes.count == 2)
        #expect(marked.count == 1)
        #expect(marked.allSatisfy { !originalIDs.contains($0.id) })
    }

    @Test func `powerless roll still marks A survivor`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 13)

        let result = try #require(ItemCorruption.apply(kinds: [.upgradeRarity], to: item, using: &rng))

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

    @Test func `add affix alone does not force astral`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let result = try #require(ItemCorruption.apply(
            kinds: [.addAffix],
            to: item,
            using: &rng,
        ))
        #expect(result.item.affixes.count == 3)
        #expect(result.item.rarity == .basic)
        #expect(!result.effects.contains(.upgradedRarity))
    }

    @Test func `rolled rarity upgrade promotes basic to astral`() throws {
        let item = try makeItem(baseID: "longsword", rarity: .basic, affixCount: 2)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let result = try #require(ItemCorruption.apply(
            kinds: [.upgradeRarity],
            to: item,
            using: &rng,
        ))
        #expect(result.item.rarity == .astral)
        #expect(result.effects.contains(.upgradedRarity))
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
        let result = try #require(ItemCorruption.apply(
            kinds: [.bumpDown],
            to: item,
            using: &rng,
        ))
        #expect(result.item.isCorrupted)
        #expect(!result.item.affixes.isEmpty)
    }

    @Test func `new affix direction uses the standard two to one weights`() {
        let original = ItemAffixPower(
            description: "Gain 5 Health.", modifiers: [.maximumHealth(5)],
        )
        var directions = Set<Int>()
        for seed in UInt64(1) ... 64 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            var reference = rng
            let ticket = Int.random(in: 1 ... 60, using: &reference)
            let expected: ItemAffixPowerBumpDirection = ticket <= 40 ? .up : .down
            var power = original
            let direction = ItemCorruption.bumpNewAffix(power: &power, using: &rng)
            #expect(direction == expected)
            #expect(power.modifiers == [.maximumHealth(expected == .up ? 6 : 4)])
            #expect(power.description == "Gain \(expected == .up ? 6 : 4) Health.")
            directions.insert(expected == .up ? 1 : -1)
        }
        #expect(directions == [-1, 1])
    }

    @Test func `new minimum values increase and on off powers remain unchanged`() throws {
        let minimums = [
            ItemAffixPower(description: "Gain 1 Health.", modifiers: [.maximumHealth(1)]),
            ItemAffixPower(description: "Gain 1% more Gold.", modifiers: [.goldGainedPercent(0.01)]),
        ]
        let expected = [
            ItemAffixPower(description: "Gain 2 Health.", modifiers: [.maximumHealth(2)]),
            ItemAffixPower(description: "Gain 2% more Gold.", modifiers: [.goldGainedPercent(0.02)]),
        ]
        for (index, original) in minimums.enumerated() {
            var power = original
            var rng = MaximumRandomNumberGenerator()
            #expect(ItemCorruption.bumpNewAffix(power: &power, using: &rng) == .up)
            #expect(power == expected[index])
        }
        let branding = try #require(GameContent.itemAffixDefinition(matching: "branding"))
        var power = branding.basic
        var rng = MaximumRandomNumberGenerator()
        #expect(ItemCorruption.bumpNewAffix(power: &power, using: &rng) == nil)
        #expect(power == branding.basic)
    }

    @Test func `structural affixes get exactly one bump at final rarity`() throws {
        let base = try #require(GameContent.itemBaseType(matching: "longsword"))
        var fixtureRNG = SeededRandomNumberGenerator(seed: 1772)
        let item = ItemGenerator().generate(
            id: "structural-sword", baseType: base, rarity: .basic,
            fixedAffixCount: 1, using: &fixtureRNG,
        )
        let combinations: [Set<CorruptionEffectKind>] = [
            [.addAffix], [.replaceAffix], [.replaceAffix, .bumpUp, .bumpDown],
            [.addAffix, .replaceAffix, .bumpUp, .bumpDown],
            [.addAffix, .replaceAffix, .upgradeRarity, .bumpUp, .bumpDown],
        ]
        for kinds in combinations {
            for seed in UInt64(1) ... 16 {
                var rng = SeededRandomNumberGenerator(seed: seed)
                let result = try #require(ItemCorruption.apply(kinds: kinds, to: item, using: &rng))
                let powers = try #require(result.item.affixPowers)
                for (index, affix) in result.item.affixes.enumerated() {
                    let isNew = result.effects.contains { effect in
                        switch effect {
                        case let .addedAffix(title), let .replacedAffix(_, title): title == affix.title
                        default: false
                        }
                    }
                    guard isNew else { continue }
                    let definition = try #require(GameContent.itemAffixDefinition(matching: affix.id))
                    let baseline = definition.power(for: result.item.rarity)
                    let bumps = result.effects.filter {
                        $0 == .bumpedUp(affixTitle: affix.title) || $0 == .bumpedDown(affixTitle: affix.title)
                    }
                    if baseline.hasBumpableField(direction: .up) {
                        #expect(bumps.count == 1)
                        let direction: ItemAffixPowerBumpDirection = bumps.first == .bumpedUp(affixTitle: affix.title)
                            ? .up : .down
                        let possible = baseline.bumpCandidates(direction: direction).map {
                            baseline.bumped(target: $0, direction: direction)
                        }
                        #expect(possible.contains { $0 == powers[index] })
                        #expect(powers[index] != baseline)
                    } else {
                        #expect(bumps.isEmpty)
                        #expect(powers[index] == baseline)
                    }
                    #expect(affix.description == powers[index].description)
                }
            }
        }
    }
}

private struct MaximumRandomNumberGenerator: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        .max
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
