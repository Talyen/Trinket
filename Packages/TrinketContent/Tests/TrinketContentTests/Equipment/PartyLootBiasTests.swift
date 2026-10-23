import Testing
import TrinketCore
@testable import TrinketContent

struct PartyLootBiasTests {
    private var bias: PartyLootBias {
        var roster = PlayerRosterState.testSeed
        roster.activeHeroID = "knight"
        roster.activeCompanionID = "bear"
        return PartyLootBias(roster: roster)
    }

    @Test func `party weights favor either character and cap shared keyword overlap`() {
        #expect(bias.weight(for: [.holy]) == 6)
        #expect(bias.weight(for: [.physical]) == 6)
        #expect(bias.weight(for: [.block]) == 7)
        #expect(bias.weight(for: [.block, .stun, .holy, .physical]) == 7)
        #expect(bias.weight(for: [.burn]) == 4)
        #expect(bias.weight(for: []) == 4)
    }

    @Test(arguments: [ItemDropTier.trinket, .unique], [false, true])
    func `collectible bias is moderate and retains off party candidates`(tier: ItemDropTier, boss: Bool) throws {
        let catalog = tier == .trinket ? GameContent.trinketItems : GameContent.uniqueItems
        let aligned = try #require(catalog.first { $0.keywords.contains(.block) })
        let unrelated = try #require(catalog.first { bias.weight(for: $0.keywords) == 4 })
        let pool: Set<String> = [aligned.templateID, unrelated.templateID]
        var alignedCount = 0
        for seed in UInt64(0) ..< 2000 {
            var random = SeededRandomNumberGenerator(seed: seed)
            let item: InventoryItem = if boss {
                BattleLoot.rollItem(
                    LootRequest(seedSalt: "boss", itemID: "weighted"), modifier: nil,
                    encounterLevel: 40, enemyIsBoss: true,
                    ownership: RewardOwnership(
                        ownedTrinketIDs: Set(GameContent.trinketItems.map(\.templateID)).subtracting(tier == .trinket ? pool : []),
                        ownedUniqueIDs: Set(GameContent.uniqueItems.map(\.templateID)).subtracting(tier == .unique ? pool : []),
                    ),
                    astralChanceBonusPercent: 0, partyBias: bias, using: &random,
                )
            } else {
                ItemRewardGenerator.generate(
                    id: "weighted", rewardLevel: 40, allowedTiers: [tier],
                    ownedTrinketIDs: [], ownedUniqueIDs: [], partyBias: bias,
                    eligibleTrinketIDs: pool, eligibleUniqueIDs: pool, using: &random,
                )
            }
            #expect(pool.contains(item.templateID))
            if item == aligned {
                alignedCount += 1
            }
        }
        // Equal baseline weights become 7:4, about 64%, without a guarantee.
        #expect((1180 ... 1380).contains(alignedCount))
        var random = SeededRandomNumberGenerator(seed: 9)
        let finalCandidate = ItemRewardGenerator.generate(
            id: "off-party", rewardLevel: 40, allowedTiers: [tier],
            ownedTrinketIDs: [aligned.templateID], ownedUniqueIDs: [aligned.templateID], partyBias: bias,
            eligibleTrinketIDs: pool, eligibleUniqueIDs: pool, using: &random,
        )
        #expect(finalCandidate == unrelated)
    }

    @Test func `gear affix weighting preserves counts and does not force alignment`() throws {
        let base = try #require(GameContent.itemBaseTypes.first {
            $0.slot != .trinket && $0.keywordAffinities.contains(.block) && $0.keywordAffinities.contains(.dodge)
        })
        let power = try #require(GameContent.itemAffixDefinitions.first { $0.slot == base.slot }).basic
        let definitions = [Keyword.block, .dodge].map { keyword in
            ItemAffixDefinition(
                id: "test-\(keyword.rawValue)", title: "Test", slot: base.slot,
                keywords: [keyword], weight: 1, basic: power, astral: power,
            )
        }
        let generator = ItemGenerator(affixDefinitions: definitions)
        var blockCount = 0
        for seed in UInt64(0) ..< 2000 {
            var random = SeededRandomNumberGenerator(seed: seed)
            let item = generator.generate(
                id: "weighted-gear", baseType: base, rarity: .basic, fixedAffixCount: 1,
                partyBias: bias, using: &random,
            )
            #expect(item.affixes.count == 1)
            if item.keywords.contains(.block) {
                blockCount += 1
            }
        }
        #expect((1180 ... 1380).contains(blockCount))
    }

    @Test func `party weighting preserves wish coin and source tier rolls`() throws {
        let wish = try #require(GameContent.uniqueItems.first { !($0.keywords.contains(.block)) })
        for seed in UInt64(0) ..< 128 {
            var expected = SeededRandomNumberGenerator(seed: seed)
            let picksWish = Int.random(in: 0 ... 1, using: &expected) == 0
            var random = SeededRandomNumberGenerator(seed: seed)
            let item = ItemWish.select(
                from: GameContent.uniqueItems, wishedTemplateID: wish.templateID,
                partyBias: bias, using: &random,
            )
            #expect((item == wish) == picksWish)
            let request = LootRequest(seedSalt: "party-tier", itemID: "party-tier")
            for boss in [false, true] {
                var ordinaryRandom = SeededRandomNumberGenerator(seed: seed)
                var biasedRandom = SeededRandomNumberGenerator(seed: seed)
                let ordinary = BattleLoot.rollItem(
                    request, modifier: nil, encounterLevel: 40, enemyIsBoss: boss, ownership: RewardOwnership(),
                    astralChanceBonusPercent: 0, using: &ordinaryRandom,
                )
                let weighted = BattleLoot.rollItem(
                    request, modifier: nil, encounterLevel: 40, enemyIsBoss: boss, ownership: RewardOwnership(),
                    astralChanceBonusPercent: 0, partyBias: bias, using: &biasedRandom,
                )
                #expect(ordinary.rarity == weighted.rarity && ordinary.isTrinket == weighted.isTrinket)
            }
        }
    }
}
