import Testing
import TrinketCore
@testable import TrinketContent

struct BattleLootTests {
    @Test(arguments: [false, true], [false, true])
    func `boss draws only remaining global collectibles then astral`(trinketsComplete: Bool, uniquesComplete: Bool) throws {
        let trinket = try #require(GameContent.trinketItems.last)
        let unique = try #require(GameContent.uniqueItems.last)
        let ownership = RewardOwnership(
            ownedTrinketIDs: Set(GameContent.trinketItems.filter { trinketsComplete || $0.templateID != trinket.templateID }
                .map(\.templateID)),
            ownedUniqueIDs: Set(GameContent.uniqueItems.filter { uniquesComplete || $0.templateID != unique.templateID }.map(\.templateID)),
        )
        let context = BattleLootContext(worldSeed: 42, ownership: ownership, astralChanceBonusPercent: 100)
        for spire in GameContent.spires {
            let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 10))
            let item = context.spire(for: floor).item
            if trinketsComplete, uniquesComplete {
                #expect(item.rarity == .astral && !item.isTrinket)
            } else if trinketsComplete {
                #expect(item.templateID == unique.templateID)
            } else if uniquesComplete {
                #expect(item.templateID == trinket.templateID)
            } else {
                #expect([trinket.templateID, unique.templateID].contains(item.templateID))
            }
        }
    }

    @Test(arguments: RewardModifier.allCases.filter(\.isItemFocused))
    func `legacy boss item modifiers pay Gold without replacing guaranteed item`(modifier: RewardModifier) {
        let request = LootRequest(seedSalt: "boss", itemID: "boss", rewardModifier: modifier)
        let legacy = BattleLoot.resolve(request, encounterLevel: 1, enemyIsBoss: true, worldSeed: 42, ownership: RewardOwnership())
        let gold = BattleLoot.resolve(
            LootRequest(seedSalt: "boss", itemID: "boss", rewardModifier: .gold),
            encounterLevel: 1, enemyIsBoss: true, worldSeed: 42, ownership: RewardOwnership(),
        )
        #expect(legacy == gold)
        #expect(legacy.item.isTrinket || legacy.item.rarity == .unique)
        #expect(RewardOwnership().resolved(modifier, enemyIsBoss: true) == .gold)
        #expect(NodeModifierCatalog.modifiers(ids: [NodeModifierCatalog.rewardID(modifier)], enemyIsBoss: true).first?
            .effect == .reward(.gold))
    }

    @Test func `opening Journey boss guarantees a Trinket only until its reward is claimed`() throws {
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-10"))
        for seed in UInt64(0) ..< 16 {
            let fresh = BattleLootContext(worldSeed: seed)
            #expect(fresh.journey(for: stage).item.isTrinket)
            let claimed = BattleLootContext(worldSeed: seed, claimedJourneyRewardStageIDs: [stage.id])
            #expect(claimed.journey(for: stage) == BattleLoot.resolve(
                .journey(stage: stage), encounterLevel: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: GameContent.chapters),
                enemyIsBoss: true, worldSeed: seed, ownership: RewardOwnership(),
            ))
        }
        let ownership = RewardOwnership(ownedTrinketIDs: Set(GameContent.trinketItems.map(\.templateID)))
        #expect(BattleLootContext(worldSeed: 42, ownership: ownership).journey(for: stage).item.rarity == .unique)
        let full = RewardOwnership(
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: Set(GameContent.uniqueItems.map(\.templateID)),
        )
        #expect(BattleLootContext(worldSeed: 42, ownership: full).journey(for: stage).item.rarity == .astral)
    }

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
