import os
import TrinketContent
import TrinketCore

extension PlayerSaveSanitizer {
    static func sanitizeRoster(
        _ roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        heroIDs: Set<String> = Set(GameContent.heroes.map(\.id)),
        companionIDs: Set<String> = Set(GameContent.companions.map(\.id)),
    ) -> PlayerRosterState {
        let validCombatantIDs = heroIDs.union(companionIDs)

        var sanitized = roster
        sanitized.gold = PlayerRosterState.clampedGoldBalance(roster.gold)
        sanitized.unlockedHeroIDs = roster.unlockedHeroIDs.intersection(heroIDs)
        sanitized.unlockedCompanionIDs = roster.unlockedCompanionIDs.intersection(companionIDs)

        if sanitized.unlockedHeroIDs.isEmpty {
            logger.notice("Sanitized roster: injected starter hero (unlocked set was empty)")
            sanitized.unlockedHeroIDs = [PlayerRosterState.starterHeroID]
        }
        if sanitized.unlockedCompanionIDs.isEmpty {
            logger.notice("Sanitized roster: injected starter companion (unlocked set was empty)")
            sanitized.unlockedCompanionIDs = [PlayerRosterState.starterCompanionID]
        }

        let (resolvedHeroID, resolvedCompanionID) = RosterHydration.resolveActiveSelection(
            activeHeroID: sanitized.activeHeroID,
            activeCompanionID: sanitized.activeCompanionID,
            unlockedHeroIDs: sanitized.unlockedHeroIDs,
            unlockedCompanionIDs: sanitized.unlockedCompanionIDs,
        )
        sanitized.activeHeroID = resolvedHeroID
        sanitized.activeCompanionID = resolvedCompanionID

        sanitized.equipmentLoadouts = RosterHydration.resolveEquipmentLoadouts(
            from: roster.equipmentLoadouts,
            inventoryItems: inventory.items,
        )

        sanitized.abilityLoadouts = RosterHydration.resolveAbilityLoadouts(
            from: roster.abilityLoadouts,
        )

        sanitized.progressions = sanitizeProgressions(
            roster.progressions,
            validCombatantIDs: validCombatantIDs,
        )

        sanitized.unlockedTalents = sanitizeUnlockedTalents(
            roster.unlockedTalents,
            validCombatantIDs: validCombatantIDs,
            progressions: sanitized.progressions,
        )

        return sanitized
    }

    static func sanitizeUnlockedTalents(
        _ talents: [String: Set<String>],
        validCombatantIDs: Set<String>,
        progressions: [String: CombatantProgression] = [:],
    ) -> [String: Set<String>] {
        var sanitized: [String: Set<String>] = [:]
        for (combatantID, nodeIDs) in talents {
            guard validCombatantIDs.contains(combatantID) else { continue }
            let validNodeIDs = CombatantTalentCatalog.validNodeIDs(for: combatantID)
            var filtered = nodeIDs.intersection(validNodeIDs)
            let budget = progressions[combatantID]?.totalTalentPoints ?? 0
            if let config = CombatantTalentCatalog.configIfAvailable(for: combatantID) {
                filtered = config.cappedUnlocks(filtered, budget: budget)
            } else {
                #if DEBUG
                assertionFailure("Missing talent config for \(combatantID) during sanitize")
                #endif
            }
            if !filtered.isEmpty {
                sanitized[combatantID] = filtered
            }
        }
        return sanitized
    }

    static func sanitizeProgressions(
        _ progressions: [String: CombatantProgression],
        validCombatantIDs: Set<String>,
    ) -> [String: CombatantProgression] {
        var sanitized: [String: CombatantProgression] = [:]
        for (combatantID, progression) in progressions {
            guard validCombatantIDs.contains(combatantID) else { continue }
            var level = max(1, progression.level)
            var currentXP = max(0, progression.currentXP)
            var requiredXP = CombatantProgression.requiredXP(forLevel: level)
            // Overflow implies pending levels (addingExperience never leaves
            // currentXP >= requiredXP). Level up to preserve earned XP instead
            // of truncating it.
            while requiredXP > 0, currentXP >= requiredXP, level < Int.max {
                currentXP -= requiredXP
                level += 1
                requiredXP = CombatantProgression.requiredXP(forLevel: level)
            }
            if level == Int.max, requiredXP > 0 {
                currentXP = min(currentXP, requiredXP - 1)
            }
            sanitized[combatantID] = CombatantProgression(
                level: level,
                currentXP: currentXP,
                requiredXP: requiredXP,
            )
        }
        return sanitized
    }
}
