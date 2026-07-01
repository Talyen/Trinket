struct PlayerInventoryState: Equatable, Hashable {
    var items: [InventoryItem]

    static var freshStart: PlayerInventoryState {
        PlayerInventoryState(items: [])
    }

    static var testSeed: PlayerInventoryState {
        PlayerInventoryState(items: GameContent.sampleInventoryItems)
    }

    static var initial: PlayerInventoryState {
        testSeed
    }

    func item(matching id: String?) -> InventoryItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    func items(for slot: ItemSlot) -> [InventoryItem] {
        items.filter { $0.baseType.slot == slot }
    }

    func hasItem(for slot: ItemSlot) -> Bool {
        items.contains { $0.baseType.slot == slot }
    }

    mutating func addRewardItem(from template: InventoryItem, for stage: Stage) {
        var randomNumberGenerator = SystemRandomNumberGenerator()
        addRewardItem(from: template, for: stage, using: &randomNumberGenerator)
    }

    mutating func addRewardItem<RNG: RandomNumberGenerator>(
        from template: InventoryItem,
        for stage: Stage,
        using randomNumberGenerator: inout RNG
    ) {
        let rewardItem = ItemGenerator().generate(
            id: "\(stage.id)-\(template.templateID)",
            templateID: template.templateID,
            baseType: template.baseType,
            rarity: template.rarity,
            using: &randomNumberGenerator
        )
        guard !items.contains(where: { $0.id == rewardItem.id }) else { return }
        items.append(rewardItem)
    }
}

struct PlayerRosterState: Equatable {
    static let starterHeroID = "knight"
    static let starterPetID = "bear"

    var activeHeroID: String
    var activePetID: String
    var unlockedHeroIDs: Set<String>
    var unlockedPetIDs: Set<String>
    var abilityLoadouts: [String: AbilityLoadout]
    var progressions: [String: CombatantProgression]
    var equipmentLoadouts: [String: EquipmentLoadout]
    var gold: Int = 0

    static var freshStart: PlayerRosterState {
        PlayerRosterState(
            activeHeroID: starterHeroID,
            activePetID: starterPetID,
            unlockedHeroIDs: [starterHeroID],
            unlockedPetIDs: [starterPetID],
            abilityLoadouts: [:],
            progressions: [
                starterHeroID: .initial,
                starterPetID: .initial
            ],
            equipmentLoadouts: [:]
        )
    }

    static var testSeed: PlayerRosterState {
        PlayerRosterState(
            activeHeroID: starterHeroID,
            activePetID: "wolf",
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedPetIDs: Set(GameContent.pets.map(\.id)),
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

    static var initial: PlayerRosterState {
        testSeed
    }

    func isUnlocked(_ combatant: Combatant) -> Bool {
        switch combatant.role {
        case .hero:
            return unlockedHeroIDs.contains(combatant.id)
        case .pet:
            return unlockedPetIDs.contains(combatant.id)
        case .enemy:
            return false
        }
    }

    func isHeroUnlocked(_ heroID: String) -> Bool {
        unlockedHeroIDs.contains(heroID)
    }

    func isPetUnlocked(_ petID: String) -> Bool {
        unlockedPetIDs.contains(petID)
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

    func battleConfiguredCombatant(_ combatant: Combatant) -> Combatant {
        let configured = configuredCombatant(combatant)
        guard combatant.role != .enemy else { return configured }

        let unlockedLoadout = configured.abilityLoadout.unlocked(for: progression(for: combatant))
        return configured.withAbilityLoadoutPreservingEmptyTiers(unlockedLoadout)
    }

    func battleConfiguredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        combatants.map(battleConfiguredCombatant)
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

    mutating func setActiveHero(_ hero: Combatant) {
        guard isUnlocked(hero) else { return }
        activeHeroID = hero.id
    }

    mutating func setActivePet(_ pet: Combatant) {
        guard isUnlocked(pet) else { return }
        activePetID = pet.id
    }

    mutating func grantExperience(_ amount: Int, to combatant: Combatant) {
        progressions[combatant.id] = progression(for: combatant).addingExperience(amount)
    }

    mutating func grantGold(_ amount: Int) {
        guard amount > 0 else { return }
        gold += amount
    }

    func equippedItem(
        for slot: ItemSlot,
        combatant: Combatant,
        inventory: PlayerInventoryState
    ) -> InventoryItem? {
        inventory.item(matching: equipmentLoadout(for: combatant).itemID(for: slot))
    }
}
