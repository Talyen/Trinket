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
        let equippedItems = resolveEquippedItems(
            combatant: combatant,
            loadout: equipmentLoadout,
            inventory: inventory,
        )

        var profile = CombatModifierProfile.zero
        for item in equippedItems {
            profile.merge(affixProfile(for: item))
        }
        if !unlockedTalents.isEmpty {
            profile.merge(CombatantTalentCatalog.profile(for: unlockedTalents))
        }
        profile.merge(additionalModifiers)
        if profile.rangedDamageDealtBonus > 0, equippedItems.contains(where: \.baseType.isRanged) {
            profile.damageDealtBonus[.physical, default: 0] += profile.rangedDamageDealtBonus
        }

        if profile.rangedDamageDealtPercent > 0, equippedItems.contains(where: \.baseType.isRanged) {
            profile.damageDealtPercents[.physical, default: 0] += profile.rangedDamageDealtPercent
        }

        return CombatBuild(combatant: combatant, modifiers: profile)
    }

    public static func build(
        enemy: Enemy,
    ) -> CombatBuild {
        CombatBuild(combatant: enemy.combatant, modifiers: traitProfile(for: enemy))
    }

    public static func build(
        enemy: Enemy,
        level: Int,
    ) -> CombatBuild {
        var profile = traitProfile(for: enemy)
        profile.outgoingDamagePercent += EnemyPowerCurve.rawDamagePercent(level: level, isBoss: enemy.isBoss)

        let scaledCombatant = CombatantLevelScaler.scale(enemy: enemy, level: level)

        return CombatBuild(combatant: scaledCombatant, modifiers: profile)
    }

    private static func resolveEquippedItems(
        combatant: Combatant,
        loadout: EquipmentLoadout,
        inventory: [InventoryItem],
    ) -> [InventoryItem] {
        let itemIDs = combatant.role.equipmentSlots.compactMap { loadout.itemID(for: $0) }
        var unresolvedIDs = Set(itemIDs)
        guard !unresolvedIDs.isEmpty else { return [] }
        var itemsByID: [String: InventoryItem] = [:]
        itemsByID.reserveCapacity(unresolvedIDs.count)
        for item in inventory {
            // First inventory match wins; merge order still follows equipment slots.
            guard unresolvedIDs.remove(item.id) != nil else { continue }
            itemsByID[item.id] = item
            if unresolvedIDs.isEmpty {
                break
            }
        }
        return itemIDs.compactMap { itemsByID[$0] }
    }

    private static func traitProfile(for enemy: Enemy) -> CombatModifierProfile {
        var profile = CombatModifierProfile.zero
        for trait in GameContent.traits(for: enemy) {
            trait.apply(to: &profile)
        }
        return profile
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
