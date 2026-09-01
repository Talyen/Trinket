import Foundation
import TrinketContent
import TrinketCore

public enum CombatBuildResolver {
    public static func build(
        combatant: Combatant,
        equipmentLoadout: EquipmentLoadout,
        inventory: [InventoryItem],
        unlockedTalents: Set<String> = [],
        additionalModifiers: [AffixModifier] = [],
    ) -> CombatBuild {
        let inventoryByID = Dictionary(inventory.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let equippedItems = combatant.role.equipmentSlots.compactMap { slot -> InventoryItem? in
            guard let itemID = equipmentLoadout.itemID(for: slot) else { return nil }
            return inventoryByID[itemID]
        }

        var profile = CombatModifierProfile.zero
        for item in equippedItems {
            profile.merge(affixProfile(for: item))
        }
        if !unlockedTalents.isEmpty {
            profile.merge(CombatantTalentCatalog.profile(for: unlockedTalents))
        }
        profile.merge(additionalModifiers)

        return CombatBuild(combatant: combatant, modifiers: profile)
    }

    public static func build(
        enemy: Enemy,
    ) -> CombatBuild {
        var profile = CombatModifierProfile.zero
        if let trait = GameContent.trait(for: enemy) {
            trait.apply(to: &profile)
            profile.traitDisplayName = trait.name
        }

        return CombatBuild(combatant: enemy.combatant, modifiers: profile)
    }

    public static func build(
        enemy: Enemy,
        level: Int,
    ) -> CombatBuild {
        var profile = CombatModifierProfile.zero
        if let trait = GameContent.trait(for: enemy) {
            trait.apply(to: &profile)
            profile.traitDisplayName = trait.name
        }
        profile.outgoingDamagePercent += EnemyPowerCurve.rawDamagePercent(level: level, isBoss: enemy.isBoss)

        let scaledCombatant = CombatantLevelScaler.scale(enemy: enemy, level: level)

        return CombatBuild(combatant: scaledCombatant, modifiers: profile)
    }

    private static func affixProfile(
        for item: InventoryItem,
    ) -> CombatModifierProfile {
        item.affixes.enumerated().reduce(into: CombatModifierProfile.zero) { partial, element in
            let (index, affix) = element
            guard let power = item.resolvedPower(at: index) else { return }
            partial.merge(power.modifiers)
            power.triggers.apply(to: &partial, abilityName: affix.title)
        }
    }
}
