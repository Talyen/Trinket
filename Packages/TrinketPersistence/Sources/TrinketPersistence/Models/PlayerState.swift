import Foundation
import TrinketContent
import TrinketCore

public struct PlayerInventoryState: Equatable, Hashable, Sendable {
    public var items: [InventoryItem]

    public init(items: [InventoryItem]) {
        self.items = items
    }

    public static var freshStart: PlayerInventoryState {
        PlayerInventoryState(items: [])
    }

    public static var testSeed: PlayerInventoryState {
        PlayerInventoryState(items: GameContent.sampleInventoryItems)
    }

    public static var initial: PlayerInventoryState {
        testSeed
    }

    public func item(matching id: String?) -> InventoryItem? {
        guard let id else { return nil }
        if let exact = items.first(where: { $0.id == id }) {
            return exact
        }
        return items.first { $0.templateID == id }
    }

    public func items(for slot: ItemSlot) -> [InventoryItem] {
        let catalogSlot = slot.baseItemSlot
        return items.filter { $0.baseType.slot == catalogSlot }
    }

    public func hasItem(for slot: ItemSlot) -> Bool {
        items.contains { $0.baseType.slot == slot.baseItemSlot }
    }
}

public struct PlayerRosterState: Equatable, Sendable {
    public static let starterHeroID = "ranger"
    public static let starterCompanionID = "wolf"

    public var activeHeroID: String
    public var activeCompanionID: String
    public var unlockedHeroIDs: Set<String>
    public var unlockedCompanionIDs: Set<String>
    public var abilityLoadouts: [String: AbilityLoadout]
    public var progressions: [String: CombatantProgression]
    public var equipmentLoadouts: [String: EquipmentLoadout]

    /// The highest level among unlocked heroes. Returns 1 if no progression data exists.
    public var highestHeroLevel: Int {
        unlockedHeroIDs.compactMap { progressions[$0]?.level }.max() ?? 1
    }

    /// The highest level among unlocked companions. Returns 1 if no progression data exists.
    public var highestCompanionLevel: Int {
        unlockedCompanionIDs.compactMap { progressions[$0]?.level }.max() ?? 1
    }

    public static let maxGoldBalance = 999

    public var gold: Int = 0 {
        didSet {
            gold = Self.clampedGoldBalance(gold)
        }
    }

    public var primaryStatOverrides: [String: PrimaryStats] = [:]

    public init(
        activeHeroID: String,
        activeCompanionID: String,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
        abilityLoadouts: [String: AbilityLoadout],
        progressions: [String: CombatantProgression],
        equipmentLoadouts: [String: EquipmentLoadout],
        gold: Int = 0,
        primaryStatOverrides: [String: PrimaryStats] = [:]
    ) {
        self.activeHeroID = activeHeroID
        self.activeCompanionID = activeCompanionID
        self.unlockedHeroIDs = unlockedHeroIDs
        self.unlockedCompanionIDs = unlockedCompanionIDs
        self.abilityLoadouts = abilityLoadouts
        self.progressions = progressions
        self.equipmentLoadouts = equipmentLoadouts
        self.gold = Self.clampedGoldBalance(gold)
        self.primaryStatOverrides = primaryStatOverrides
    }

    public static var freshStart: PlayerRosterState {
        PlayerRosterState(
            activeHeroID: starterHeroID,
            activeCompanionID: starterCompanionID,
            unlockedHeroIDs: [starterHeroID],
            unlockedCompanionIDs: [starterCompanionID],
            abilityLoadouts: [:],
            progressions: [
                starterHeroID: .initial,
                starterCompanionID: .initial
            ],
            equipmentLoadouts: [:]
        )
    }

    public static var testSeed: PlayerRosterState {
        PlayerRosterState(
            activeHeroID: starterHeroID,
            activeCompanionID: "wolf",
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
            abilityLoadouts: [:],
            progressions: [
                "knight": CombatantProgression(level: 2, currentXP: 35, requiredXP: 155),
                "rogue": CombatantProgression(level: 1, currentXP: 65, requiredXP: 100),
                "wizard": CombatantProgression(level: 3, currentXP: 20, requiredXP: 220),
                "alchemist": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "druid": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "ranger": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "warlock": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "bear": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "frost_whelp": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "lizard_scout": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "panther": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "phoenix": CombatantProgression(level: 1, currentXP: 0, requiredXP: 100),
                "wolf": CombatantProgression(level: 2, currentXP: 12, requiredXP: 155)
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

    public static var initial: PlayerRosterState {
        testSeed
    }

    public func isUnlocked(_ combatant: Combatant) -> Bool {
        switch combatant.role {
        case .hero:
            unlockedHeroIDs.contains(combatant.id)
        case .companion:
            unlockedCompanionIDs.contains(combatant.id)
        case .enemy:
            false
        }
    }

    public func isHeroUnlocked(_ heroID: String) -> Bool {
        unlockedHeroIDs.contains(heroID)
    }

    public func isCompanionUnlocked(_ companionID: String) -> Bool {
        unlockedCompanionIDs.contains(companionID)
    }

    public func loadout(for combatant: Combatant) -> AbilityLoadout {
        abilityLoadouts[combatant.id] ?? combatant.abilityLoadout
    }

    public mutating func setLoadout(_ loadout: AbilityLoadout, for combatant: Combatant) {
        let configuredCombatant = combatant.withAbilityLoadout(loadout)
        abilityLoadouts[combatant.id] = configuredCombatant.abilityLoadout
    }

    public func configuredCombatant(_ combatant: Combatant) -> Combatant {
        let withLoadout = combatant.withAbilityLoadout(loadout(for: combatant))
        guard let overrides = primaryStatOverrides[combatant.id] else { return withLoadout }
        return withLoadout.withPrimaryStats(overrides)
    }

    public func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        combatants.map(configuredCombatant)
    }

    public func battleConfiguredCombatant(_ combatant: Combatant) -> Combatant {
        let configured = configuredCombatant(combatant)
        guard combatant.role != .enemy else { return configured }

        let unlockedLoadout = configured.abilityLoadout.unlocked(for: progression(for: combatant))
        return configured.withAbilityLoadoutPreservingEmptyTiers(unlockedLoadout)
    }

    public func battleConfiguredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        combatants.map(battleConfiguredCombatant)
    }

    public func progression(for combatant: Combatant) -> CombatantProgression {
        progressions[combatant.id] ?? .initial
    }

    public func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        equipmentLoadouts[combatant.id] ?? EquipmentLoadout()
    }

    public mutating func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        let newlyEquipped = Set(loadout.itemIDsBySlot.values)
        for (combatantID, var otherLoadout) in equipmentLoadouts where combatantID != combatant.id {
            for slot in ItemSlot.allCases {
                if let itemID = otherLoadout.itemID(for: slot), newlyEquipped.contains(itemID) {
                    otherLoadout.unequip(slot)
                }
            }
            equipmentLoadouts[combatantID] = otherLoadout
        }
        equipmentLoadouts[combatant.id] = loadout
    }

    public mutating func setActiveHero(_ hero: Combatant) {
        guard isUnlocked(hero) else { return }
        activeHeroID = hero.id
    }

    public mutating func setActiveCompanion(_ companion: Combatant) {
        guard isUnlocked(companion) else { return }
        activeCompanionID = companion.id
    }

    /// Unlocks a hero or companion and seeds baseline progression when missing.
    /// Returns `true` when the combatant was newly unlocked.
    @discardableResult
    public mutating func unlock(_ combatant: Combatant) -> Bool {
        switch combatant.role {
        case .hero:
            unlockHero(id: combatant.id)
        case .companion:
            unlockCompanion(id: combatant.id)
        case .enemy:
            false
        }
    }

    /// Unlocks a hero by catalog id. Returns `true` when newly unlocked.
    @discardableResult
    public mutating func unlockHero(id heroID: String) -> Bool {
        guard GameContent.heroes.contains(where: { $0.id == heroID }) else { return false }
        let inserted = unlockedHeroIDs.insert(heroID).inserted
        if progressions[heroID] == nil {
            progressions[heroID] = .initial
        }
        return inserted
    }

    /// Unlocks a companion by catalog id. Returns `true` when newly unlocked.
    @discardableResult
    public mutating func unlockCompanion(id companionID: String) -> Bool {
        guard GameContent.companions.contains(where: { $0.id == companionID }) else { return false }
        let inserted = unlockedCompanionIDs.insert(companionID).inserted
        if progressions[companionID] == nil {
            progressions[companionID] = .initial
        }
        return inserted
    }

    /// Unlocks every catalog hero and companion, setting each progression to `level`.
    public mutating func unlockAllCombatants(atLevel level: Int = 20) {
        let progression = CombatantProgression.at(level: level)
        unlockedHeroIDs = Set(GameContent.heroes.map(\.id))
        unlockedCompanionIDs = Set(GameContent.companions.map(\.id))
        for heroID in unlockedHeroIDs {
            progressions[heroID] = progression
        }
        for companionID in unlockedCompanionIDs {
            progressions[companionID] = progression
        }
    }

    public func isCombatantUnlocked(id combatantID: String) -> Bool {
        unlockedHeroIDs.contains(combatantID) || unlockedCompanionIDs.contains(combatantID)
    }

    public mutating func grantExperience(_ amount: Int, to combatant: Combatant) {
        progressions[combatant.id] = progression(for: combatant).addingExperience(amount)
    }

    public mutating func grantGold(_ amount: Int) {
        guard amount > 0 else { return }
        let current = Self.clampedGoldBalance(gold)
        gold = current + min(amount, Self.maxGoldBalance - current)
    }

    public static func clampedGoldBalance(_ amount: Int) -> Int {
        min(max(amount, 0), maxGoldBalance)
    }

    /// Deducts gold when the roster can afford `amount`. Returns `false` without mutating
    /// when `amount` is non-positive or exceeds the current balance.
    @discardableResult
    public mutating func spendGold(_ amount: Int) -> Bool {
        guard amount > 0, gold >= amount else { return false }
        gold -= amount
        return true
    }

    public func equippedItem(
        for slot: ItemSlot,
        combatant: Combatant,
        inventory: PlayerInventoryState
    ) -> InventoryItem? {
        inventory.item(matching: equipmentLoadout(for: combatant).itemID(for: slot))
    }

    public var heroes: [Combatant] {
        battleConfiguredCombatants(
            GameContent.heroes.filter { isUnlocked($0) }
        )
    }

    public var companions: [Combatant] {
        battleConfiguredCombatants(
            GameContent.companions.filter { isUnlocked($0) }
        )
    }

    public var collectionHeroes: [Combatant] {
        orderedCollectionCombatants(GameContent.heroes)
    }

    public var collectionCompanions: [Combatant] {
        orderedCollectionCombatants(GameContent.companions)
    }

    public var activeHero: Combatant {
        heroes.first { $0.id == activeHeroID } ??
            heroes.first ??
            GameContent.heroes.first { $0.id == PlayerRosterState.starterHeroID } ??
            collectionHeroes[0]
    }

    public var activeCompanion: Combatant {
        companions.first { $0.id == activeCompanionID } ??
            companions.first ??
            GameContent.companions.first { $0.id == PlayerRosterState.starterCompanionID } ??
            collectionCompanions[0]
    }

    private func orderedCollectionCombatants(_ combatants: [Combatant]) -> [Combatant] {
        configuredCombatants(combatants)
            .enumerated()
            .sorted { left, right in
                let leftUnlocked = isUnlocked(left.element)
                let rightUnlocked = isUnlocked(right.element)

                if leftUnlocked != rightUnlocked {
                    return leftUnlocked
                }

                if leftUnlocked {
                    let leftLevel = progression(for: left.element).level
                    let rightLevel = progression(for: right.element).level
                    if leftLevel != rightLevel {
                        return leftLevel > rightLevel
                    }
                }

                // Preserve authored catalog order for equal-level and locked entries.
                return left.offset < right.offset
            }
            .map(\.element)
    }
}
