import TrinketContent
import TrinketCore

/// A read-only detail value shared by battle and collection presentations.
/// Inventory is passed as a value snapshot so presentation code never needs to
/// know about the persistence model that supplied it.
public struct CombatantCardDetail: Hashable, Identifiable {
    public let combatant: Combatant
    public let progression: CombatantProgression
    public let equipmentLoadout: EquipmentLoadout
    public let inventoryItems: [InventoryItem]
    public let health: Int?
    public let activeEffectSummaries: [EffectSummary]
    public let labyrinthModifiers: [LabyrinthModifierDefinition]

    public var id: String {
        combatant.id
    }

    public init(
        combatant: Combatant,
        progression: CombatantProgression = .initial,
        equipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
        inventoryItems: [InventoryItem] = [],
        health: Int? = nil,
        activeEffectSummaries: [EffectSummary] = [],
        labyrinthModifiers: [LabyrinthModifierDefinition] = []
    ) {
        self.combatant = combatant
        self.progression = progression
        self.equipmentLoadout = equipmentLoadout
        self.inventoryItems = inventoryItems
        self.health = health
        self.activeEffectSummaries = activeEffectSummaries
        self.labyrinthModifiers = labyrinthModifiers
    }
}
