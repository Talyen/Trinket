import BattleEngine
import TrinketContent
import TrinketCore
import TrinketPersistence

struct CombatantDetailContext: Identifiable, Hashable {
    enum Kind: Hashable {
        case hero
        case pet
    }

    let kind: Kind
    let combatantID: String

    var id: String {
        "\(kind)-\(combatantID)"
    }
}

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
        let rosterContext = configuration.rosterContext(for: combatant.id)
        return CombatantCardDetail(
            combatant: combatant,
            progression: rosterContext?.progression ?? .initial,
            equipmentLoadout: rosterContext?.equipmentLoadout ?? EquipmentLoadout(),
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
