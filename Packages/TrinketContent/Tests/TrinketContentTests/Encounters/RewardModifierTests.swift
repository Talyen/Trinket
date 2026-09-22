import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct RewardModifierTests {
    @Test func `reward identifiers round trip and preserve existing saves`() throws {
        for modifier in RewardModifier.allCases {
            let encoded = try JSONEncoder().encode(modifier)
            #expect(try JSONDecoder().decode(RewardModifier.self, from: encoded) == modifier)
            #expect(try JSONDecoder().decode(String.self, from: encoded) == modifier.rawValue)
            #expect(RewardModifier(rawValue: modifier.rawValue) == modifier)
        }
        #expect(try JSONDecoder().decode(RewardModifier.self, from: Data(#""gold""#.utf8)) == .gold)
        #expect(try JSONDecoder().decode(RewardModifier.self, from: Data(#""keyword.deathsDoor""#.utf8)) == .keyword(.deathsDoor))
        #expect(RewardModifier(rawValue: "keyword.deathsDoor") == .keyword(.deathsDoor))
        #expect(RewardModifier(rawValue: "unknown") == nil)
        #expect(RewardModifier(rawValue: "keyword.unknown") == nil)
        #expect(Set(RewardModifier.allCases.map(\.rawValue)).count == RewardModifier.allCases.count)
    }

    @Test(arguments: Keyword.allCases, [false, true])
    func `every keyword guarantees matching generated gear with normal affix counts`(keyword: Keyword, boss: Bool) throws {
        let matchingBases = GameContent.itemBaseTypes.filter { base in
            base.slot != .trinket && base.keywordAffinities.contains(keyword)
                && GameContent.itemAffixDefinitions.contains { $0.isEligible(for: base) && $0.keywords.contains(keyword) }
        }
        #expect(!matchingBases.isEmpty)
        for tier in [ItemDropTier.basic, .astral] {
            for seed in UInt64(1) ... 8 {
                var rng = SeededRandomNumberGenerator(seed: seed)
                let item = ItemRewardGenerator.generate(
                    id: "guaranteed", rewardLevel: 20, bossContent: boss, allowedTiers: [tier], requiredKeyword: keyword,
                    ownedTrinketIDs: [], ownedUniqueIDs: [], using: &rng,
                )
                #expect(!item.isTrinket)
                #expect(item.rarity == (tier == .basic ? .basic : .astral))
                #expect(item.baseType.keywordAffinities.contains(keyword))
                #expect(item.affixes.contains { $0.keywords.contains(keyword) })
                #expect((tier == .basic ? 1 ... 2 : 3 ... 4).contains(item.affixes.count))
                #expect(Set(item.affixes.map(\.id)).count == item.affixes.count)
                for affix in item.affixes {
                    let definition = try #require(GameContent.itemAffixDefinition(matching: affix.id))
                    #expect(definition.isEligible(for: item.baseType))
                }
                var retry = SeededRandomNumberGenerator(seed: seed)
                #expect(item == ItemRewardGenerator.generate(
                    id: "guaranteed", rewardLevel: 20, bossContent: boss, allowedTiers: [tier], requiredKeyword: keyword,
                    ownedTrinketIDs: [], ownedUniqueIDs: [], using: &retry,
                ))
            }
        }
    }

    @Test(arguments: [false, true])
    func `keyword rewards preserve relative basic astral tier weights`(boss: Bool) {
        let probabilities = ItemLootPolicy.probabilities(
            level: 30, bossContent: boss, astralChanceBonusPercent: 30, availableTiers: [.basic, .astral],
        )
        for seed in UInt64(1) ... 64 {
            var expectedRNG = SeededRandomNumberGenerator(seed: seed)
            let expected = ItemLootPolicy.roll(probabilities: probabilities, using: &expectedRNG)
            var rng = SeededRandomNumberGenerator(seed: seed)
            let item = ItemRewardGenerator.generate(
                id: "tier", rewardLevel: 30, bossContent: boss, astralChanceBonusPercent: 30, requiredKeyword: .bleed,
                ownedTrinketIDs: [], ownedUniqueIDs: [], using: &rng,
            )
            #expect(item.rarity == (expected == .basic ? .basic : .astral))
        }
    }

    @Test func `reward expansion preserves category odds and excludes exhausted collectibles`() throws {
        let eligible = RewardModifier.eligible(
            ownedTrinketIDs: Set(GameContent.trinketItems.map(\.templateID)),
            ownedUniqueIDs: Set(GameContent.uniqueItems.map(\.templateID)),
        )
        for enemy in [GameContent.enemies.first { !$0.isBoss }, GameContent.enemies.first { $0.isBoss }].compactMap(\.self) {
            let type: LabyrinthNodeType = enemy.isBoss ? .boss : .battle
            let combatCount = LabyrinthCatalog.combatModifiers(for: enemy.id, nodeType: type).count(where: {
                if case .reward = $0.effect {
                    false
                } else {
                    true
                }
            })
            var rng = SeededRandomNumberGenerator(seed: 9)
            var rewardCount = 0
            var seen: Set<RewardModifier> = []
            var previous: LabyrinthModifierID?
            for _ in 0 ..< 3000 {
                let id = try #require(LabyrinthCatalog.pickModifier(
                    for: type, enemyID: enemy.id, eligibleRewards: eligible, excluding: previous, using: &rng,
                ))
                #expect(id != previous)
                previous = id
                let definition = try #require(LabyrinthCatalog.modifier(id: id))
                if case let .reward(reward) = definition.effect {
                    #expect(eligible.contains(reward))
                    rewardCount += 1
                    seen.insert(reward)
                }
            }
            #expect(abs(Double(rewardCount) / 3000 - 3 / Double(combatCount + 3)) < 0.035)
            #expect(seen == Set(eligible))
        }
    }

    @Test func `repair excludes exhausted rewards without rerolling valid saved IDs`() throws {
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let exhaustedID = LabyrinthCatalog.rewardID(.unique)
        #expect(LabyrinthCatalog.resolvedModifierIDs(
            for: .battle, enemyID: enemy.id, existingModifierIDs: [exhaustedID],
            worldSeed: 7, nodeID: "saved", eligibleRewards: [.gold],
        ) == [exhaustedID])
        for seed in UInt64(1) ... 64 {
            let repaired = LabyrinthCatalog.resolvedModifierIDs(
                for: .battle, enemyID: enemy.id, existingModifierIDs: [LabyrinthModifierID("unknown")],
                worldSeed: seed, nodeID: "repaired", eligibleRewards: [.gold],
            )
            let definition = try #require(LabyrinthCatalog.modifiers(ids: repaired).first)
            if case let .reward(reward) = definition.effect {
                #expect(reward == .gold)
            }
        }
    }

    @Test func `shared rewards retain legacy node IDs and combat-only eligibility`() throws {
        for (reward, id) in [(RewardModifier.gold, "bountyMark"), (.experience, "scholarsToll"), (.materials, "scavengersLuck")] {
            #expect(LabyrinthCatalog.rewardID(reward).rawValue == id)
        }
        for reward in RewardModifier.allCases {
            let id = LabyrinthCatalog.rewardID(reward)
            let definition = try #require(LabyrinthCatalog.modifier(id: id))
            #expect(definition.effect == .reward(reward))
            #expect(definition.applies(to: .battle) && definition.applies(to: .boss))
            #expect(!definition.applies(to: .shop) && !definition.applies(to: .recruit) && !definition.applies(to: .entrance))
            #expect(definition.applies(to: .mystery) == [.gold, .experience, .materials].contains(reward))
        }
    }
}
