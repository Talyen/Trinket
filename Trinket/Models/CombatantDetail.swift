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

    init(
        combatant: Combatant,
        progression: CombatantProgression = .initial,
        equipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryState: PlayerInventoryState = .initial,
        health: Int? = nil,
        activeEffectSummaries: [EffectSummary] = []
    ) {
        self.combatant = combatant
        self.progression = progression
        self.equipmentLoadout = equipmentLoadout
        self.inventoryState = inventoryState
        self.health = health ?? combatant.maxHealth
        self.activeEffectSummaries = activeEffectSummaries
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
}
