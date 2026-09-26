import Foundation
import TrinketContent
import TrinketCore

public enum SpireCompletion {
    public static func resolveLoot(
        for floor: SpireFloor,
        encounterLevel: Int? = nil,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        ownedUniqueIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0,
        modifier: NodeModifierDefinition? = nil,
    ) -> BattleLootResult {
        let level = encounterLevel ?? EncounterLevelResolver.spireEnemyLevel(for: floor)
        let enemyIsBoss = VictoryRewardApplier.isBoss(enemyID: floor.enemyID)
        let ownership = RewardOwnership(
            ownedTrinketIDs: ownedTrinketIDs,
            ownedUniqueIDs: ownedUniqueIDs,
        )
        let selected = modifier ?? GameContent.spireModifier(for: floor, worldSeed: worldSeed)
        let definitions = ownership.modifiers(ids: selected.map { [$0.id] } ?? [])
        let effects = NodeModifierEffects.combining(definitions)
        return VictoryRewardApplier.resolveLoot(
            .spire(floor: floor, rewardModifier: effects.rewardModifier),
            encounterLevel: level,
            enemyIsBoss: enemyIsBoss,
            worldSeed: worldSeed,
            ownership: ownership,
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
    }

    public static func partyAdjustedEncounterLevel(for floor: SpireFloor, save: PlayerSave) -> Int {
        VictoryRewardApplier.partyAdjustedEncounterLevel(
            authoredLevel: EncounterLevelResolver.spireEnemyLevel(for: floor),
            save: save,
        )
    }

    @discardableResult
    public static func complete(
        floor: SpireFloor,
        hero: Combatant,
        companion: Combatant,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
        save: inout PlayerSave,
    ) -> EncounterCompletion {
        let spireID = floor.spireID.rawValue
        guard let spire = GameContent.spire(id: floor.spireID) else {
            return .unavailable
        }
        guard !save.spires.isFloorCleared(floor.floor, spireID: spireID) else {
            return .alreadyCompleted
        }
        guard save.spires.isFloorStartable(
            floor.floor,
            spireID: spireID,
            floorCount: spire.floorCount,
        ) else {
            return .unavailable
        }

        let encounterLevel = enemyEncounterLevel
            ?? partyAdjustedEncounterLevel(for: floor, save: save)
        let resolvedLoot = loot ?? resolveLoot(
            for: floor,
            encounterLevel: encounterLevel,
            worldSeed: save.worldSeed,
            ownedTrinketIDs: save.inventory.ownedTrinketIDs,
            ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: resolvedLoot.gold,
            battleGold: battleGold,
            award: award,
            materialRewards: VictoryRewardApplier.grantedMaterials(
                override: materialRewards,
                loot: resolvedLoot,
            ),
            item: VictoryRewardApplier.grantedItem(override: rewardItem, loot: resolvedLoot),
            save: &save,
        )

        save.spires.markFloorCleared(floor.floor, spireID: spireID)
        return .completed
    }
}
