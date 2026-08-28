import Foundation
import TrinketContent
import TrinketCore

public struct PlayerInventoryState: Equatable, Hashable, Sendable {
    public var items: [InventoryItem]

    public init(items: [InventoryItem]) {
        self.items = items
    }

    public static var freshStart: Self {
        Self(items: [])
    }

    public static var testSeed: Self {
        Self(items: GameContent.sampleInventoryItems)
    }

    public func item(matching id: String?) -> InventoryItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    public var ownedTrinketIDs: Set<String> {
        Set(items.filter(\.isTrinket).map(\.templateID))
    }

    public var ownedUniqueIDs: Set<String> {
        Set(items.filter { $0.rarity == .unique }.map(\.templateID))
    }
}

public struct PlayerRosterState: Equatable, Sendable {
    public static let starterHeroID = "knight"
    public static let starterCompanionID = "wolf"

    public var activeHeroID: String
    public var activeCompanionID: String
    public var unlockedHeroIDs: Set<String>
    public var unlockedCompanionIDs: Set<String>
    public var abilityLoadouts: [String: AbilityLoadout]
    public var progressions: [String: CombatantProgression]
    public var equipmentLoadouts: [String: EquipmentLoadout]
    public var unlockedTalents: [String: Set<String>]

    public var highestHeroLevel: Int {
        unlockedHeroIDs.compactMap { progressions[$0]?.level }.max() ?? 1
    }

    public var highestCompanionLevel: Int {
        unlockedCompanionIDs.compactMap { progressions[$0]?.level }.max() ?? 1
    }

    public var activePartyAverageLevel: Int {
        (progression(for: activeHero).level + progression(for: activeCompanion).level) / 2
    }

    public var eligibleRecruitEventIDs: [String] {
        GameContent.recruitEvents.compactMap { event in
            guard let combatantID = event.unlockCombatantID,
                  !unlockedHeroIDs.contains(combatantID),
                  !unlockedCompanionIDs.contains(combatantID)
            else { return nil }
            return event.id
        }
    }

    public static let maxGoldBalance = 999

    public var gold: Int = 0 {
        didSet {
            gold = Self.clampedGoldBalance(gold)
        }
    }

    public init(
        activeHeroID: String,
        activeCompanionID: String,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
        abilityLoadouts: [String: AbilityLoadout],
        progressions: [String: CombatantProgression],
        equipmentLoadouts: [String: EquipmentLoadout],
        unlockedTalents: [String: Set<String>] = [:],
        gold: Int = 0
    ) {
        self.activeHeroID = activeHeroID
        self.activeCompanionID = activeCompanionID
        self.unlockedHeroIDs = unlockedHeroIDs
        self.unlockedCompanionIDs = unlockedCompanionIDs
        self.abilityLoadouts = abilityLoadouts
        self.progressions = progressions
        self.equipmentLoadouts = equipmentLoadouts
        self.unlockedTalents = unlockedTalents
        self.gold = Self.clampedGoldBalance(gold)
    }

    public static var freshStart: Self {
        Self(
            activeHeroID: starterHeroID,
            activeCompanionID: starterCompanionID,
            unlockedHeroIDs: [starterHeroID],
            unlockedCompanionIDs: [starterCompanionID],
            abilityLoadouts: [:],
            progressions: [
                starterHeroID: .initial,
                starterCompanionID: .initial,
            ],
            equipmentLoadouts: [:],
            unlockedTalents: [:]
        )
    }

    public static var testSeed: Self {
        Self(
            activeHeroID: starterHeroID,
            activeCompanionID: "wolf",
            unlockedHeroIDs: Set(GameContent.heroes.map(\.id)),
            unlockedCompanionIDs: Set(GameContent.companions.map(\.id)),
            abilityLoadouts: [:],
            progressions: [
                "knight": CombatantProgression(level: 2, currentXP: 3, requiredXP: 15),
                "rogue": CombatantProgression(level: 1, currentXP: 6, requiredXP: 10),
                "wizard": CombatantProgression(level: 3, currentXP: 2, requiredXP: 22),
                "ranger": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "warlock": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "bear": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "frost_whelp": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "lizard_scout": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "panther": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "phoenix": CombatantProgression(level: 1, currentXP: 0, requiredXP: 10),
                "wolf": CombatantProgression(level: 2, currentXP: 1, requiredXP: 15),
            ],
            equipmentLoadouts: [
                "knight": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: "longsword-basic",
                    .armor: "plate_armor-basic",
                ]),
                "wizard": EquipmentLoadout(itemIDsBySlot: [
                    .weapon: "wand-basic",
                    .accessory: "ruby_ring-basic",
                ]),
                "wolf": EquipmentLoadout(itemIDsBySlot: [
                    .accessory: "sapphire_amulet-basic",
                ]),
            ]
        )
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
        combatant.withAbilityLoadout(loadout(for: combatant))
    }

    public func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        combatants.map(configuredCombatant)
    }

    public func battleConfiguredCombatant(_ combatant: Combatant) -> Combatant {
        let configured = configuredCombatant(combatant)
        guard combatant.role != .enemy else { return configured }
        return configured.withAbilityLoadoutPreservingEmptyTiers(configured.abilityLoadout)
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

    public func equippedCombatantID(for itemID: String) -> String? {
        equipmentLoadouts.first { _, loadout in
            loadout.itemIDsBySlot.values.contains(itemID)
        }?.key
    }

    public func equippedCombatantName(for itemID: String) -> String? {
        guard let combatantID = equippedCombatantID(for: itemID) else { return nil }
        return GameContent.combatant(matching: combatantID)?.name ?? combatantID
    }

    public mutating func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        equipmentLoadouts = RosterHydration.applyLoadout(
            loadout,
            for: combatant.id,
            in: equipmentLoadouts
        )
    }

    @discardableResult
    public mutating func unequip(itemID: String) -> Bool {
        var didUnequip = false
        for (combatantID, var loadout) in equipmentLoadouts {
            var didChange = false
            for slot in ItemSlot.allCases where loadout.itemID(for: slot) == itemID {
                loadout.unequip(slot)
                didChange = true
            }
            if didChange {
                equipmentLoadouts[combatantID] = loadout
                didUnequip = true
            }
        }
        return didUnequip
    }

    public mutating func setActiveHero(_ hero: Combatant) {
        guard isUnlocked(hero) else { return }
        activeHeroID = hero.id
    }

    public mutating func setActiveCompanion(_ companion: Combatant) {
        guard isUnlocked(companion) else { return }
        activeCompanionID = companion.id
    }

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

    @discardableResult
    public mutating func unlockHero(id heroID: String) -> Bool {
        var ids = unlockedHeroIDs
        let result = unlock(id: heroID, catalog: GameContent.heroes, into: &ids)
        unlockedHeroIDs = ids
        return result
    }

    @discardableResult
    public mutating func unlockCompanion(id companionID: String) -> Bool {
        var ids = unlockedCompanionIDs
        let result = unlock(id: companionID, catalog: GameContent.companions, into: &ids)
        unlockedCompanionIDs = ids
        return result
    }

    @discardableResult
    private mutating func unlock(
        id combatantID: String,
        catalog: [Combatant],
        into unlockedIDs: inout Set<String>
    ) -> Bool {
        guard catalog.contains(where: { $0.id == combatantID }) else { return false }
        let inserted = unlockedIDs.insert(combatantID).inserted
        if progressions[combatantID] == nil {
            progressions[combatantID] = .initial
        }
        return inserted
    }

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

    @discardableResult
    public mutating func grantExperience(_ amount: Int, to combatant: Combatant) -> Int {
        let current = progression(for: combatant)
        let granted = ExperienceScaling.cappedAward(amount, for: current)
        guard granted > 0 else { return 0 }
        progressions[combatant.id] = current.addingExperience(granted)
        return granted
    }

    public mutating func grantGold(_ amount: Int) {
        guard amount > 0 else { return }
        let current = Self.clampedGoldBalance(gold)
        gold = current + min(amount, Self.maxGoldBalance - current)
    }

    public static func clampedGoldBalance(_ amount: Int) -> Int {
        min(max(amount, 0), maxGoldBalance)
    }

    @discardableResult
    public mutating func spendGold(_ amount: Int) -> Bool {
        guard amount > 0, gold >= amount else { return false }
        gold -= amount
        return true
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
        if let hero = heroes.first(where: { $0.id == activeHeroID }) ?? heroes.first {
            return hero
        }
        if let starter = GameContent.heroes.first(where: { $0.id == Self.starterHeroID })
            ?? collectionHeroes.first {
            return starter
        }
        preconditionFailure("GameContent.heroes must be non-empty")
    }

    public var activeCompanion: Combatant {
        if let companion = companions.first(where: { $0.id == activeCompanionID }) ?? companions.first {
            return companion
        }
        if let starter = GameContent.companions.first(where: {
            $0.id == Self.starterCompanionID
        }) ?? collectionCompanions.first {
            return starter
        }
        preconditionFailure("GameContent.companions must be non-empty")
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

                return left.offset < right.offset
            }
            .map(\.element)
    }
}
