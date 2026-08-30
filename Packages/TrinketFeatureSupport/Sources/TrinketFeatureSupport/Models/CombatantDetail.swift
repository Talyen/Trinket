import TrinketContent
import TrinketCore

public struct CombatantCardDetail: Hashable, Identifiable {
    public let combatant: Combatant
    public let progression: CombatantProgression
    public let equipmentLoadout: EquipmentLoadout
    public let inventoryItems: [InventoryItem]
    public let unlockedTalents: Set<String>
    public let health: Int?
    public let mana: Int?
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
        unlockedTalents: Set<String> = [],
        health: Int? = nil,
        mana: Int? = nil,
        activeEffectSummaries: [EffectSummary] = [],
        labyrinthModifiers: [LabyrinthModifierDefinition] = [],
    ) {
        self.combatant = combatant
        self.progression = progression
        self.equipmentLoadout = equipmentLoadout
        self.inventoryItems = inventoryItems
        self.unlockedTalents = unlockedTalents
        self.health = health
        self.mana = mana
        self.activeEffectSummaries = activeEffectSummaries
        self.labyrinthModifiers = labyrinthModifiers
    }
}
