import TrinketContent
import TrinketCore
import TrinketPersistence

public struct CombatantDetailContext: Identifiable, Hashable {
    public enum Kind: Hashable {
        case hero
        case companion
    }

    public let kind: Kind
    public let combatantID: String

    public var id: String {
        "\(kind)-\(combatantID)"
    }

    public init(kind: Kind, combatantID: String) {
        self.kind = kind
        self.combatantID = combatantID
    }
}

public struct CombatantCardDetail: Hashable, Identifiable {
    public let combatant: Combatant
    public let progression: CombatantProgression
    public let equipmentLoadout: EquipmentLoadout
    public let inventoryState: PlayerInventoryState
    public let health: Int?
    public let activeEffectSummaries: [EffectSummary]

    public var id: String {
        combatant.id
    }

    public init(
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
        self.health = health
        self.activeEffectSummaries = activeEffectSummaries
    }
}
