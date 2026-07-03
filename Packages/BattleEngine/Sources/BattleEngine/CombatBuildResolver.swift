import Foundation
import TrinketCore
import TrinketContent

public enum CombatBuildResolver {
    public static func build(
        combatant: Combatant,
        equipmentLoadout: EquipmentLoadout,
        inventory: [InventoryItem]
    ) -> CombatBuild {
        let itemsByID = Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0) })
        let equippedItems = ItemSlot.allCases.compactMap { slot -> InventoryItem? in
            guard let itemID = equipmentLoadout.itemID(for: slot) else { return nil }
            return itemsByID[itemID]
        }

        var profile = CombatModifierProfile.zero
        for item in equippedItems {
            profile.merge(affixProfile(for: item))
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
            primaryStats: effectiveStats
        )

        return CombatBuild(combatant: builtCombatant, modifiers: profile)
    }

    private static func affixProfile(for item: InventoryItem) -> CombatModifierProfile {
        item.affixes.reduce(into: CombatModifierProfile.zero) { partial, affix in
            guard let definition = GameContent.itemAffixDefinitions.first(where: { $0.id == affix.id }) else {
                return
            }
            let power = definition.power(for: item.rarity)
            partial.merge(power.modifiers)
        }
    }
}
