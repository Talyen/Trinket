import Testing
import TrinketCore
@testable import TrinketContent

struct BattleLootTests {
    @Test func `quantity range endpoints`() {
        #expect(BattleLoot.quantityRange(forLevel: Int.min) == 3 ... 4)
        #expect(BattleLoot.quantityRange(forLevel: 1) == 3 ... 4)
        #expect(BattleLoot.quantityRange(forLevel: 24) == 7 ... 13)
        #expect(BattleLoot.quantityRange(forLevel: 48) == 11 ... 23)
        #expect(BattleLoot.quantityRange(forLevel: 50) == 12 ... 24)
        #expect(BattleLoot.quantityRange(forLevel: Int.max / 20 + 1) == 84704437073156107 ... 188232082384791347)
        #expect(BattleLoot.quantityRange(forLevel: Int.max) == 1694088741463122090 ... 3764641647695826864)
    }

    @Test(arguments: [false, true])
    func `maximum encounter level loot retains valid quantities with boss and reward bonuses`(boss: Bool) {
        func resolve(bonus: Int) -> BattleLootResult {
            BattleLoot.resolve(
                LootRequest(seedSalt: "maximum-level", itemID: "maximum-level", goldFoundPercent: bonus, materialsFoundPercent: bonus),
                encounterLevel: Int.max, enemyIsBoss: boss, worldSeed: 42, ownership: RewardOwnership(),
            )
        }
        let base = resolve(bonus: 0)
        let boosted = resolve(bonus: RewardModifier.bonusPercent)
        let multiplier = boss ? 2 : 1
        let range = (1694088741463122090 * multiplier) ... (3764641647695826864 * multiplier)
        #expect(range.contains(base.gold))
        #expect(base.materials.count == 2)
        #expect(Set(base.materials.map(\.resource)).count == 2)
        #expect(base.materials.allSatisfy { range.contains($0.quantity) })
        #expect(boosted.gold == CombatRounding.scaled(base.gold, byPercent: RewardModifier.bonusPercent))
        #expect(boosted.materials == base.materials.map {
            ResourceAmount($0.resource, CombatRounding.scaled($0.quantity, byPercent: RewardModifier.bonusPercent))
        })
        #expect(boosted.item == base.item)
    }

    @Test(arguments: [false, true])
    func `ordinary and boss loot grants one item and two distinct material rewards`(boss: Bool) {
        let loot = BattleLoot.resolve(
            LootRequest(seedSalt: "test", itemID: "test-loot"),
            encounterLevel: 1, enemyIsBoss: boss, worldSeed: 42, ownership: RewardOwnership(),
        )
        let range = boss ? 6 ... 8 : 3 ... 4
        #expect(loot.item.isTrinket || loot.item.rarity == .unique || loot.item.id == "test-loot")
        #expect(range.contains(loot.gold))
        #expect(loot.materials.count == 2)
        #expect(Set(loot.materials.map(\.resource)).count == 2)
        #expect(loot.materials.allSatisfy {
            BattleLoot.materialResources.contains($0.resource) && range.contains($0.quantity)
        })
    }

    @Test(arguments: BattleLoot.materialResources, [false, true])
    func `focused rewards retain general material bonuses on both distinct slots`(resource: HomesteadResource, boss: Bool) throws {
        let modifier = try #require(RewardModifier(rawValue: resource.rawValue))
        func resolve(bonus: Int) -> BattleLootResult {
            BattleLoot.resolve(
                LootRequest(
                    seedSalt: "focused", itemID: "focused",
                    materialsFoundPercent: bonus - RewardModifier.bonusPercent, rewardModifier: modifier,
                ),
                encounterLevel: 20, enemyIsBoss: boss, worldSeed: 42, ownership: RewardOwnership(),
            )
        }
        let unboostedFocus = resolve(bonus: 0)
        let base = resolve(bonus: RewardModifier.bonusPercent)
        let boosted = resolve(bonus: 2 * RewardModifier.bonusPercent)
        #expect(boosted.materials.count == 2)
        #expect(Set(boosted.materials.map(\.resource)).count == 2)
        let focused = try #require(boosted.materials.first)
        #expect(focused.resource == resource)
        #expect(focused.quantity == CombatRounding.scaled(unboostedFocus.materials[0].quantity, byPercent: 2 * RewardModifier.bonusPercent))
        #expect(boosted.materials[1].resource == base.materials[1].resource)
        #expect(boosted.materials[1].quantity == CombatRounding.scaled(
            base.materials[1].quantity,
            byPercent: RewardModifier.bonusPercent,
        ))
        #expect(boosted.gold == base.gold)
        #expect(boosted.item == base.item)
    }

    @Test func `gold and general material bonuses leave other rewards unchanged`() {
        func resolve(gold: Int = 0, materials: Int = 0) -> BattleLootResult {
            BattleLoot.resolve(
                LootRequest(seedSalt: "bonus", itemID: "bonus", goldFoundPercent: gold, materialsFoundPercent: materials),
                encounterLevel: 20, enemyIsBoss: true, worldSeed: 42, ownership: RewardOwnership(),
            )
        }
        let base = resolve()
        let gold = resolve(gold: 25)
        let materials = resolve(materials: 25)
        #expect(gold.gold == CombatRounding.scaled(base.gold, byPercent: 25))
        #expect(gold.materials == base.materials && gold.item == base.item)
        #expect(materials.materials == base.materials.map {
            ResourceAmount($0.resource, CombatRounding.scaled($0.quantity, byPercent: 25))
        })
        #expect(materials.gold == base.gold && materials.item == base.item)
    }

    @Test func `journey loot is seed stable`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        func resolve(seed: UInt64) -> BattleLootResult {
            BattleLoot.resolve(
                .journey(stage: stage), encounterLevel: 1, enemyIsBoss: false,
                worldSeed: seed, ownership: RewardOwnership(),
            )
        }
        let first = resolve(seed: 8)
        #expect(first == resolve(seed: 8))
        #expect(first != resolve(seed: 9))
    }
}
