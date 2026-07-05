import BattleEngine
import TrinketContent
import TrinketCore
import TrinketPersistence

struct CombatantCardDetail: Hashable, Identifiable {
    let combatant: Combatant
    let progression: CombatantProgression
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let health: Int
    let activeEffectSummaries: [EffectSummary]

    var id: String {
        combatant.id
    }

    static func base(_ combatant: Combatant) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
            progression: .initial,
            equipmentLoadout: EquipmentLoadout(),
            inventoryState: .initial,
            health: combatant.maxHealth,
            activeEffectSummaries: []
        )
    }

    static func battleSnapshot(
        configuration: ActiveBattleConfiguration,
        combatant: Combatant,
        health: Int,
        activeEffectSummaries: [EffectSummary]
    ) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
            progression: combatant.id == configuration.hero.id
                ? configuration.heroProgression
                : combatant.id == configuration.pet.id
                    ? configuration.petProgression
                    : .initial,
            equipmentLoadout: combatant.id == configuration.hero.id
                ? configuration.heroEquipmentLoadout
                : combatant.id == configuration.pet.id
                    ? configuration.petEquipmentLoadout
                    : EquipmentLoadout(),
            inventoryState: configuration.inventoryState,
            health: health,
            activeEffectSummaries: activeEffectSummaries
        )
    }

    static func stageEnemyPreview(
        encounter: StageEncounterEnemy,
        inventoryState: PlayerInventoryState
    ) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: encounter.combatant,
            progression: .initial,
            equipmentLoadout: EquipmentLoadout(),
            inventoryState: inventoryState,
            health: encounter.combatant.maxHealth,
            activeEffectSummaries: []
        )
    }
}
