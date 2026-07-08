import Foundation
import TrinketContent
import TrinketCore

public enum CombatBuildResolver {
    public static func build(
        combatant: Combatant,
        equipmentLoadout: EquipmentLoadout,
        inventory: [InventoryItem],
        catalog: CombatCatalog = GameContentCombatCatalog()
    ) -> CombatBuild {
        let itemsByID = Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0) })
        let equippedItems = combatant.role.equipmentSlots.compactMap { slot -> InventoryItem? in
            guard let itemID = equipmentLoadout.itemID(for: slot) else { return nil }
            return itemsByID[itemID]
        }

        var profile = CombatModifierProfile.zero
        for item in equippedItems {
            profile.merge(affixProfile(for: item, catalog: catalog))
        }
        if let trait = catalog.trait(forCombatantID: combatant.id) {
            trait.apply(to: &profile)
            profile.traitDisplayName = trait.name
        }

        let effectiveStats = combatant.primaryStats.merged(with: profile.statBonuses)
        let builtCombatant = Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: combatant.maxHealth,
            maxMana: combatant.maxMana,
            actionIntervalTicks: combatant.actionIntervalTicks,
            abilityChoices: combatant.abilityChoices,
            primaryStats: effectiveStats,
            growthArchetype: combatant.growthArchetype
        )

        return CombatBuild(combatant: builtCombatant, modifiers: profile)
    }

    public static func build(
        enemy: Enemy,
        catalog: CombatCatalog = GameContentCombatCatalog()
    ) -> CombatBuild {
        var profile = CombatModifierProfile.zero
        if let positiveTrait = catalog.positiveTrait(for: enemy) {
            positiveTrait.apply(to: &profile)
            profile.traitDisplayName = positiveTrait.name
        }
        if let negativeTrait = catalog.negativeTrait(for: enemy) {
            negativeTrait.apply(to: &profile)
        }

        return CombatBuild(combatant: enemy.combatant, modifiers: profile)
    }

    private static func affixProfile(
        for item: InventoryItem,
        catalog: CombatCatalog
    ) -> CombatModifierProfile {
        item.affixes.reduce(into: CombatModifierProfile.zero) { partial, affix in
            guard let definition = catalog.itemAffixDefinition(id: affix.id) else {
                return
            }
            let power = definition.power(for: item.rarity)
            partial.merge(power.modifiers)
        }
    }
}
