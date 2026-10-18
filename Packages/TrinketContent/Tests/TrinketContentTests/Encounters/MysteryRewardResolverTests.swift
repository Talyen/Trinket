import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct MysteryRewardResolverTests {
    private func resolver(ownership: RewardOwnership) -> MysteryRewardResolver {
        MysteryRewardResolver(
            homesteadEffects: .zero, ownership: ownership,
            inputs: RewardSettlementInputs(
                gold: 0, reservedGold: 0, goldLimit: GoldBalance.maximum,
                heroProgression: .initial, companionProgression: .initial,
                productionDate: Date(timeIntervalSince1970: 0),
            ),
        )
    }

    @Test(arguments: [Int.min, 0, 1, 3, 4, 7, 50, Int.max / 14, Int.max / 14 + 1, Int.max])
    func `material scaling preserves the exact quotient across integer boundaries`(level: Int) {
        let product = UInt(max(1, level)).multipliedFullWidth(by: 14)
        let quotient = UInt(49).dividingFullWidth(product).quotient
        #expect(MysteryRewardResolver.materialQuantity(forLevel: level) == 4 + Int(quotient))
    }

    @Test func `special reward pools filter ownership independently and retain gear fallback`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        let choice = event.choices[0]
        let scenarios: [(RewardOwnership, Set<ItemDropTier>)] = [
            (RewardOwnership(), [.basic, .astral, .trinket, .unique]),
            (RewardOwnership(ownedTrinketIDs: ["icy_heart"]), [.basic, .astral, .unique]),
            (RewardOwnership(ownedUniqueIDs: ["rimeheart_locket"]), [.basic, .astral, .trinket]),
            (RewardOwnership(ownedTrinketIDs: ["icy_heart"], ownedUniqueIDs: ["rimeheart_locket"]), [.basic, .astral]),
        ]
        let unownedWeights = ItemLootPolicy.probabilities(
            level: 20, bossContent: false, astralChanceBonusPercent: 0,
            availableTiers: Set(ItemDropTier.allCases), collectibleChancePercent: 50,
        )
        for (ownership, available) in scenarios {
            let weights = ItemLootPolicy.probabilities(
                level: 20, bossContent: false, astralChanceBonusPercent: 0, availableTiers: available,
                collectibleChancePercent: 50,
            )
            for (index, tier) in ItemDropTier.allCases.enumerated() {
                // Also probe draws that would have selected an owned collectible
                // before filtering; otherwise a broken exclusion could go unseen.
                let probeWeights = available.contains(tier) ? weights : unownedWeights
                let lower = probeWeights.prefix(index).reduce(0, +)
                let upper = lower + probeWeights[index]
                // Find only the first random draw in this tier's interval, then
                // generate one real offer. The policy's weights/boundaries have
                // their own owner; this test protects Mystery's pool forwarding.
                let seed = try #require((1 ... 4096).first { seed in
                    var probe = SeededRandomNumberGenerator(seed: UInt64(seed))
                    let draw = Double.random(in: 0 ..< 1, using: &probe)
                    return draw >= lower && draw < upper
                })
                var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
                let offer = try #require(resolver(ownership: ownership).resolveOffer(
                    choice: choice, encounterID: "spring", encounterLevel: 6, rewardLevel: 20, using: &rng,
                ))
                #expect(!ownership.ownedTrinketIDs.contains(offer.item.templateID))
                #expect(!ownership.ownedUniqueIDs.contains(offer.item.templateID))
                guard available.contains(tier) else { continue }
                switch tier {
                case .trinket:
                    #expect(offer.item.templateID == "icy_heart")
                case .unique:
                    #expect(offer.item.templateID == "rimeheart_locket")
                case .basic, .astral:
                    #expect(offer.item.baseType.id == "sapphire_amulet")
                    #expect(offer.item.rarity == (tier == .basic ? .basic : .astral))
                }
            }
        }
    }

    @Test func `legacy flat rewards and combined percentages saturate at integer limits`() throws {
        func makeResolver(_ effects: HomesteadEffects) -> MysteryRewardResolver {
            MysteryRewardResolver(
                homesteadEffects: effects, ownership: RewardOwnership(),
                inputs: RewardSettlementInputs(
                    gold: 0, reservedGold: 0, goldLimit: GoldBalance.maximum,
                    heroProgression: .at(level: Int.max), companionProgression: .at(level: Int.max),
                    productionDate: Date(timeIntervalSince1970: 0),
                ),
            )
        }
        let saturated = makeResolver(HomesteadEffects(
            goldFindFlat: 1, experienceBonus: 1, gemsFindBonus: 1, experienceBonusPercent: 1,
        ))
        for (effect, expected) in [
            (MysteryEffect.gainGold(Int.max), MysteryRewardBonus.gold(Int.max)),
            (.gainMaterial(.gems), .material(.gems, Int.max)),
            (.gainExperience, .experience(Int.max)),
        ] {
            let reward = try #require(saturated.resolveReward(
                effect, encounterLevel: Int.max,
                goldPercent: Int.max, experiencePercent: Int.max, materialsPercent: Int.max,
            ))
            #expect(reward.bonus == expected)
        }
        let reduced = makeResolver(HomesteadEffects(
            goldFindPercent: Int.min, goldFindFlat: 1, experienceBonus: 1, experienceBonusPercent: Int.min,
        ))
        #expect(reduced.resolveReward(
            .gainGold(10), encounterLevel: 1,
            goldPercent: -1, experiencePercent: 0, materialsPercent: 0,
        )?.bonus == .gold(1))
        #expect(reduced.resolveReward(
            .gainExperience, encounterLevel: 1,
            goldPercent: 0, experiencePercent: -1, materialsPercent: 0,
        )?.bonus == .experience(1))
    }

    @Test(arguments: [HomesteadResource.gold, .gems])
    func `offer settlement preserves flat bonuses beside percentage remainders`(resource: HomesteadResource) throws {
        let resolver = MysteryRewardResolver(
            homesteadEffects: HomesteadEffects(goldFindPercent: 5, goldFindFlat: 3, gemsFindBonus: 3, gemsFindPercent: 5),
            ownership: RewardOwnership(),
            inputs: RewardSettlementInputs(
                gold: 0, reservedGold: 0, goldLimit: GoldBalance.maximum,
                heroProgression: .initial, companionProgression: .initial,
                productionDate: Date(timeIntervalSince1970: 0),
            ),
        )
        let item = try #require(GameContent.sampleInventoryItems.first)
        let effect: MysteryEffect = resource == .gold ? .gainGold(10) : .gainMaterial(.gems)
        let reward = try #require(resolver.resolveReward(
            effect, encounterLevel: 1, goldPercent: 0, experiencePercent: 0, materialsPercent: 0,
        ))
        let settled = resolver.settledBonus(
            reward.bonus, homesteadReward: reward.homestead, encounterLevel: 1,
        )
        let expected: MysteryRewardBonus = resource == .gold ? .gold(13) : .material(.gems, 7)
        #expect(settled == expected)
        #expect(resolver.hasCurrentHomesteadReward(MysteryOffer(
            choiceID: "take", item: item, bonus: settled, homesteadReward: reward.homestead,
        )))
    }
}
