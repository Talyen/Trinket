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

    @Test func `special rewards stay inside the choice pool and exclude owned items`() throws {
        let event = try #require(GameContent.mysteryEvent(matching: "enchanted-spring"))
        let choice = event.choices[0]
        var seen: Set<String> = []
        var ownership = RewardOwnership()
        var rng = SeededRandomNumberGenerator(seed: 42)
        for _ in 0 ..< 100 {
            let offer = try #require(resolver(ownership: ownership).resolveOffer(
                choice: choice, encounterID: "spring", encounterLevel: 6, rewardLevel: 20, using: &rng,
            ))
            if offer.item.isTrinket || offer.item.rarity == .unique {
                #expect(["icy_heart", "rimeheart_locket"].contains(offer.item.templateID))
                seen.insert(offer.item.templateID)
            } else {
                #expect(offer.item.baseType.id == "sapphire_amulet")
            }
        }
        #expect(seen == ["icy_heart", "rimeheart_locket"])
        for id in seen {
            let item = try #require(GameContent.itemTemplate(matching: id) ?? GameContent.unique(matching: id))
            if item.isTrinket {
                ownership.ownedTrinketIDs.insert(id)
            } else {
                ownership.ownedUniqueIDs.insert(id)
            }
        }
        for _ in 0 ..< 20 {
            let offer = try #require(resolver(ownership: ownership).resolveOffer(
                choice: choice, encounterID: "spring", encounterLevel: 6, rewardLevel: 20, using: &rng,
            ))
            #expect(!offer.item.isTrinket && offer.item.rarity != .unique)
            #expect(offer.item.baseType.id == "sapphire_amulet")
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
}
