import Foundation
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
        let hasRanged = equippedItems.contains(where: \.baseType.isRanged)
        if profile.rangedDamageDealtBonus != 0, hasRanged {
            profile.damageDealtBonus[.physical] = SaturatedArithmetic.saturatingAdd(
                profile.damageDealtBonus[.physical, default: 0], profile.rangedDamageDealtBonus,
            )
        }

        if profile.rangedDamageDealtPercent != 0, hasRanged {
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
        profile powerProfile: EnemyPowerCurve.Profile = .standard,
    ) -> CombatBuild {
        var profile = traitProfile(for: enemy)
        profile.outgoingDamagePercent += EnemyPowerCurve.rawDamagePercent(level: level, isBoss: enemy.isBoss, profile: powerProfile)
        if powerProfile == .standard, enemy.id == "the_blood_countess" {
            if level < 20 {
                // Ease early pressure without changing her shared Bleed cards.
                let progress = Double(max(level, 1) - 1) / 19
                let eased = progress * progress * (3 - 2 * progress)
                profile.outgoingDamagePercent -= 0.20 * (1 - eased)
            } else if level > 20 {
                // Preserve the level-forty adjustment and common post-forty slope.
                let progress = Double(min(level, 40) - 20) / 20
                profile.outgoingDamagePercent -= 0.65 * progress * progress * (3 - 2 * progress)
            }
            // Ease the additional midgame adjustment in after level four and
            // back out by forty, preserving both previously verified anchors.
            let midProgress = if level <= 20 {
                Double(min(max(level, 4), 20) - 4) / 16
            } else {
                Double(40 - min(level, 40)) / 20
            }
            profile.outgoingDamagePercent -= 0.40 * midProgress * midProgress * (3 - 2 * midProgress)
        }

        let scaledCombatant = CombatantLevelScaler.scale(enemy: enemy, level: level, profile: powerProfile)

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
