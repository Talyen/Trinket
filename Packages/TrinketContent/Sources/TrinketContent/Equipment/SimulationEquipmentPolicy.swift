import TrinketCore

/// Shared headless/career heuristic; it does not rank gear for the player UI.
public enum SimulationEquipmentPolicy {
    public static let id = "effect-aligned-affix-budget-v3"

    public struct Upgrade: Equatable, Sendable {
        public let itemID: String
        public let slot: ItemSlot
        /// Commit this removal before equipping; its cost is included in the upgrade score.
        public let unequipFirst: ItemSlot?
    }

    /// Retain ties, respect other owners, and compare the entire resulting legal
    /// loadout so replacing a primary includes any displaced secondary's cost.
    public static func nextUpgrade(
        for combatant: Combatant,
        inventory: [InventoryItem],
        loadout: EquipmentLoadout,
        reservedItemIDs: Set<String> = [],
    ) -> Upgrade? {
        let current = loadout.sanitized(for: combatant, inventory: inventory)
        let worn = Set(current.itemIDsBySlot.values)
        var secondaryIsQuiver: Bool?
        var scorer = Scorer(combatant: combatant, inventory: inventory)
        var best = scorer.score(current)
        var upgrade: Upgrade?
        let candidates = inventory.lazy.filter { !worn.contains($0.id) && !reservedItemIDs.contains($0.id) }
            .sorted { $0.id < $1.id }
        for item in candidates {
            for slot in combatant.role.equipmentSlots {
                var candidate = current
                let unequipFirst: ItemSlot?
                if slot == .weapon, !item.baseType.isRanged {
                    if secondaryIsQuiver == nil {
                        secondaryIsQuiver = current.itemID(for: .secondaryWeapon).flatMap { secondaryID in
                            inventory.first { $0.id == secondaryID }
                        }?.baseType.isQuiver == true
                    }
                    if secondaryIsQuiver == true {
                        candidate.unequip(.secondaryWeapon)
                        unequipFirst = .secondaryWeapon
                    } else {
                        unequipFirst = nil
                    }
                } else {
                    unequipFirst = nil
                }
                guard candidate.canEquip(item, in: slot, inventory: inventory) else { continue }
                candidate.equip(item, in: slot, inventory: inventory)
                candidate = candidate.sanitized(for: combatant, inventory: inventory)
                let value = scorer.score(candidate)
                if value.isImprovement(over: best) {
                    best = value
                    upgrade = Upgrade(itemID: item.id, slot: slot, unequipFirst: unequipFirst)
                }
            }
        }
        return upgrade
    }

    private struct AffixKey: Hashable {
        let id: String
        let rarity: Rarity
        let multiplier: Int
    }

    private struct Score {
        var budget = 0
        var items = 0
        var portfolio: [AffixKey: Int] = [:]
        var rolls: [AffixKey: [Double]] = [:]

        mutating func add(_ value: Self) {
            budget += value.budget
            for (key, count) in value.portfolio {
                portfolio[key, default: 0] += count
            }
            for (key, magnitudes) in value.rolls {
                let previous = rolls[key, default: Array(repeating: 0.0, count: magnitudes.count)]
                rolls[key] = zip(previous, magnitudes).map(+)
            }
        }

        func isImprovement(over other: Self) -> Bool {
            if budget != other.budget {
                return budget > other.budget
            }
            if items != other.items {
                return items > other.items
            }
            // Rolls order the same effects only; unlike defensive/offensive kits stay tied.
            guard portfolio == other.portfolio else { return false }
            var improves = false
            for (key, magnitudes) in rolls {
                guard let previous = other.rolls[key], magnitudes.count == previous.count else { return false }
                for (current, old) in zip(magnitudes, previous) {
                    guard current >= old else { return false }
                    improves = improves || current > old
                }
            }
            return improves
        }
    }

    private struct Scorer {
        let combatant: Combatant
        let keywords: Set<Keyword>
        let inventory: [InventoryItem]
        let powers: [String: [ItemAffixPower?]]
        var cachedValues: [Set<Keyword>: [String: Score]] = [:]

        init(combatant: Combatant, inventory: [InventoryItem]) {
            self.combatant = combatant
            self.inventory = inventory
            keywords = Set(combatant.abilities.lazy.flatMap(\.keywords))
            powers = Dictionary(uniqueKeysWithValues: inventory.lazy.map { item in
                (item.id, item.affixes.indices.map { item.resolvedPower(at: $0) })
            })
        }

        mutating func score(_ loadout: EquipmentLoadout) -> Score {
            let worn = Set(loadout.itemIDsBySlot.values)
            var bonusKeywords = keywords
            // Damage-bonus sharing does not grant Physical/Bleed attacks or their procs.
            for id in worn {
                for power in powers[id, default: []].lazy.compactMap(\.self) {
                    if power.triggers.physicalBonusesApplyToHoly, keywords.contains(.holy) {
                        bonusKeywords.insert(.physical)
                    }
                    if power.triggers.burnAndBleedShareDamageBonuses {
                        if keywords.contains(.burn) {
                            bonusKeywords.insert(.bleed)
                        }
                        if keywords.contains(.bleed) {
                            bonusKeywords.insert(.burn)
                        }
                    }
                }
            }
            if cachedValues[bonusKeywords] == nil {
                cachedValues[bonusKeywords] = Dictionary(uniqueKeysWithValues: inventory.map { item in
                    (item.id, value(item, bonusKeywords: bonusKeywords))
                })
            }
            let values = cachedValues[bonusKeywords, default: [:]]
            return worn.sorted().reduce(into: Score()) { result, id in
                let value = values[id, default: Score()]
                result.add(value)
                result.items += 1
            }
        }

        private func value(_ item: InventoryItem, bonusKeywords: Set<Keyword>) -> Score {
            var result = Score()
            for (index, affix) in item.affixes.enumerated() {
                let power = powers[item.id]?[index]
                guard isAligned(affix, power: power, bonusKeywords: bonusKeywords) else { continue }
                // Retain the coarse affix budget; actual rolls break otherwise equal budgets.
                let budget = item.baseType.affixPowerMultiplier * (item.rarity == .basic ? 1 : 2)
                result.budget += budget
                let reference = GameContent.itemAffixDefinition(matching: affix.id)?.power(for: item.rarity)
                    .scaled(by: item.baseType.affixPowerMultiplier)
                let key = AffixKey(id: affix.id, rarity: item.rarity, multiplier: item.baseType.affixPowerMultiplier)
                result.portfolio[key, default: 0] += 1
                if let power, let reference {
                    let magnitudes = power.relativeMagnitudes(to: reference)
                    let previous = result.rolls[key, default: Array(repeating: 0.0, count: magnitudes.count)]
                    result.rolls[key] = zip(previous, magnitudes).map(+)
                }
            }
            return result
        }

        private func isAligned(_ affix: ItemAffix, power: ItemAffixPower?, bonusKeywords: Set<Keyword>) -> Bool {
            guard let power else { return legacyAlignment(affix) }
            if power.modifiers.contains(where: { isRelevant($0, bonusKeywords: bonusKeywords) }) {
                return true
            }
            let triggers = power.triggers
            if triggers.physicalBonusesApplyToHoly {
                return keywords.contains(.holy)
            }
            if triggers.burnAndBleedShareDamageBonuses {
                return keywords.contains(.burn) || keywords.contains(.bleed)
            }
            return !triggers.populatedFields.isEmpty && legacyAlignment(affix)
        }

        private func legacyAlignment(_ affix: ItemAffix) -> Bool {
            affix.keywords.allSatisfy { $0.category != .damageType || keywords.contains($0) }
                && (combatant.hasMana || !affix.keywords.contains(.mana))
        }

        private func isRelevant(_ modifier: AffixModifier, bonusKeywords: Set<Keyword>) -> Bool {
            guard modifier.numericValue > 0 else { return false }
            switch modifier {
            case let .damageDealt(keyword, _), let .damageDealtPercent(keyword, _):
                return bonusKeywords.contains(keyword)
            case .poisonDamageDealtPercent: return keywords.contains(.poison)
            case .bleedDuration: return keywords.contains(.bleed)
            case .maximumMana, .maximumManaPercent, .manaRestored, .manaRestoredPercent:
                return combatant.hasMana
            case .damageTakenVulnerability: return false
            default: return true
            }
        }
    }
}
