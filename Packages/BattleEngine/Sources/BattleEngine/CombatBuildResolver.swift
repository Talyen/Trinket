import Foundation
import TrinketContent
import TrinketCore

public enum CombatBuildResolver {
    public static func build(
        combatant: Combatant,
        equipmentLoadout: EquipmentLoadout,
        inventory: [InventoryItem],
        additionalModifiers: [AffixModifier] = []
    ) -> CombatBuild {
        let itemsByID = Dictionary(inventory.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let equippedItems = combatant.role.equipmentSlots.compactMap { slot -> InventoryItem? in
            guard let itemID = equipmentLoadout.itemID(for: slot) else { return nil }
            return itemsByID[itemID]
        }

        var profile = CombatModifierProfile.zero
        for item in equippedItems {
            profile.merge(affixProfile(for: item))
        }
        if let trait = GameContent.trait(forCombatantID: combatant.id) {
            trait.apply(to: &profile)
            profile.traitDisplayName = trait.name
        }
        profile.merge(additionalModifiers)

        let effectiveStats = combatant.primaryStats.merged(with: profile.statBonuses)
        let builtCombatant = Combatant(
            id: combatant.id,
            name: combatant.name,
            role: combatant.role,
            maxHealth: combatant.maxHealth,
            maxMana: combatant.maxMana,
            actionIntervalTurns: combatant.actionIntervalTurns,
            abilityChoices: combatant.abilityChoices,
            primaryStats: effectiveStats,
            growthArchetype: combatant.growthArchetype
        )

        return CombatBuild(combatant: builtCombatant, modifiers: profile)
    }

    public static func build(
        enemy: Enemy
    ) -> CombatBuild {
        var profile = CombatModifierProfile.zero
        if let trait = GameContent.trait(for: enemy) {
            trait.apply(to: &profile)
            profile.traitDisplayName = trait.name
        }

        return CombatBuild(combatant: enemy.combatant, modifiers: profile)
    }

    private static func affixProfile(
        for item: InventoryItem
    ) -> CombatModifierProfile {
        item.affixes.enumerated().reduce(into: CombatModifierProfile.zero) { partial, element in
            let (index, _) = element
            guard let power = item.resolvedPower(at: index) else { return }
            partial.merge(power.modifiers)
            power.triggers.apply(to: &partial)
        }
    }
}
