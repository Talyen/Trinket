struct PlayerInventoryState: Equatable, Hashable {
    var items: [InventoryItem]

    static var initial: PlayerInventoryState {
        PlayerInventoryState(items: GameContent.sampleInventoryItems)
    }

    func item(matching id: String?) -> InventoryItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    func items(for slot: ItemSlot) -> [InventoryItem] {
        items.filter { $0.baseType.slot == slot }
    }
}

struct PlayerRosterState: Equatable {
    var activeHeroID: String
    var activePetID: String
    var abilityLoadouts: [String: AbilityLoadout]
    var progressions: [String: CombatantProgression]
    var equipmentLoadouts: [String: EquipmentLoadout]
    var gold: Int = 0

    static var initial: PlayerRosterState {
        PlayerRosterState(
            activeHeroID: GameContent.heroes.first?.id ?? "",
            activePetID: GameContent.pets.first?.id ?? "",
            abilityLoadouts: [:],
            progressions: [
                "knight": CombatantProgression(level: 2, currentXP: 35, requiredXP: 120),
                "rogue": CombatantProgression(level: 1, currentXP: 65, requiredXP: 100),
                "wizard": CombatantProgression(level: 3, currentXP: 20, requiredXP: 160),
                "alchemist": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "druid": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "ranger": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "warlock": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "wildcard": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "bear": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "frost_whelp": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "imp": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "lizard_scout": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "panther": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "phoenix": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "wolf": CombatantProgression(level: 2, currentXP: 12, requiredXP: 100)
            ],
            equipmentLoadouts: [
                "knight": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: "longsword-basic",
                    .armor: "plate_armor-basic"
                ]),
                "wizard": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: "wand-basic",
                    .trinket: "ruby_ring-basic"
                ]),
                "wolf": EquipmentLoadout(itemIDsBySlot: [
                    .armor: "leather_armor-basic"
                ])
            ]
        )
    }

    func loadout(for combatant: Combatant) -> AbilityLoadout {
        abilityLoadouts[combatant.id] ?? combatant.abilityLoadout
    }

    mutating func setLoadout(_ loadout: AbilityLoadout, for combatant: Combatant) {
        let configuredCombatant = combatant.withAbilityLoadout(loadout)
        abilityLoadouts[combatant.id] = configuredCombatant.abilityLoadout
    }

    func configuredCombatant(_ combatant: Combatant) -> Combatant {
        combatant.withAbilityLoadout(loadout(for: combatant))
    }

    func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        combatants.map(configuredCombatant)
    }

    func progression(for combatant: Combatant) -> CombatantProgression {
        progressions[combatant.id] ?? .initial
    }

    func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        equipmentLoadouts[combatant.id] ?? EquipmentLoadout()
    }

    mutating func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        equipmentLoadouts[combatant.id] = loadout
    }

    func equippedItem(
        for slot: ItemSlot,
        combatant: Combatant,
        inventory: PlayerInventoryState
    ) -> InventoryItem? {
        inventory.item(matching: equipmentLoadout(for: combatant).itemID(for: slot))
    }
}
