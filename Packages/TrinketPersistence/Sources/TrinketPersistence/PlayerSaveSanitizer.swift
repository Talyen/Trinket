import Foundation
import os
import TrinketContent
import TrinketCore

enum PlayerSaveSanitizer {
    static let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSaveSanitizer",
    )

    static func sanitize(_ save: PlayerSave) -> PlayerSave {
        sanitize(save, changedSlices: .all)
    }

    /// Single sanitize→validate entry for commit, reset, and cloud-restore
    /// paths. Doctrine is heal-locally / reject-remotely: local callers pass
    /// a sanitize that repairs (negative gold, duplicates, ghost equipment,
    /// stale stage IDs, unreadable maps) and validation is the safety net
    /// for what repair cannot heal (schema mismatch, unencodable powers);
    /// cloud-restore callers rely on the same validation to refuse corrupt
    /// snapshots before they can propagate. The store-open path deliberately
    /// uses sanitize-only so a locally readable save always loads.
    static func sanitizeAndValidate(_ save: PlayerSave, changedSlices: PlayerSaveSlice = .all) throws -> PlayerSave {
        let sanitized = sanitize(save, changedSlices: changedSlices)
        #if DEBUG
        for (_, progression) in sanitized.roster.progressions {
            assert(
                progression.level >= 1 && progression.currentXP >= 0 && progression.requiredXP > 0,
                "sanitizeProgressions must heal level/XP/requiredXP; validate skips the redundant check",
            )
        }
        #endif
        try validate(sanitized)
        return sanitized
    }

    static func sanitize(_ save: PlayerSave, changedSlices: PlayerSaveSlice) -> PlayerSave {
        var sanitized = save
        let targets = PlayerSaveSlice.sanitizeTargets(for: changedSlices)
        sanitized.worldSeed = resolvedWorldSeed(save, seedIfMissing: changedSlices.contains(.root))
        if changedSlices.contains(.labyrinth),
           !sanitized.labyrinth.isMapPayloadUnreadable,
           save.worldSeed == 0 || !sanitized.labyrinth.hasMap || sanitized.labyrinth.worldSeed == 0 {
            sanitized.labyrinth.worldSeed = sanitized.worldSeed
        }
        if targets.contains(.root) {
            sanitized.corruptionAltarCooldownRemaining = max(0, save.corruptionAltarCooldownRemaining)
        }
        // These dependent repairs are ordered here, independent of enum declaration order.
        if targets.contains(.inventory) {
            sanitized.inventory = sanitizeInventory(save.inventory)
        }
        if targets.contains(.roster) {
            sanitized.roster = sanitizeRoster(save.roster, inventory: sanitized.inventory)
        }
        if targets.contains(.homestead) {
            sanitized.homestead = sanitizeHomestead(save.homestead)
        }
        if targets.contains(.journey) {
            sanitized.journey = sanitizeJourney(save.journey)
        }
        if targets.contains(.spires) {
            sanitized.spires = sanitizeSpires(save.spires)
        }
        if targets.contains(.voyage) {
            sanitized.voyage = save.voyage.sanitized()
        }
        if targets.contains(.contracts) {
            sanitized.contracts = save.contracts.sanitized()
        }
        if targets.contains(.labyrinth) {
            sanitized.labyrinth = sanitizeLabyrinth(
                sanitized.labyrinth,
                eligibleRecruitEventIDs: sanitized.roster.eligibleRecruitEventIDs,
                eligibleRewards: RewardOwnership(sanitized).eligibleModifiers,
            )
        }
        return sanitized
    }

    static func resolvedWorldSeed(_ save: PlayerSave, seedIfMissing: Bool = true) -> UInt64 {
        if save.worldSeed != 0 {
            return save.worldSeed
        }
        if save.labyrinth.hasMap {
            let existing = save.labyrinth.worldSeed
            return existing == 0 ? LabyrinthGenerator.fallbackWorldSeed : existing
        }
        guard seedIfMissing else { return 0 }
        return PlayerSave.makeWorldSeed()
    }

    static func validate(_ save: PlayerSave) throws {
        guard save.schemaVersion == PlayerSave.currentSchemaVersion else {
            throw PlayerSavePersistenceError.invalidSave("Unsupported save schema version.")
        }
        guard !save.labyrinth.hasMap || save.labyrinth.mapVersion == LabyrinthGenerator.currentMapVersion else {
            throw PlayerSavePersistenceError.invalidSave("Unsupported Labyrinth map version.")
        }
        guard save.roster.gold >= 0 else {
            throw PlayerSavePersistenceError.invalidSave("Roster gold cannot be negative.")
        }
        guard save.corruptionAltarCooldownRemaining >= 0 else {
            throw PlayerSavePersistenceError.invalidSave("Corruption altar cooldown cannot be negative.")
        }
        for (_, amount) in save.homestead.resources where amount < 0 {
            throw PlayerSavePersistenceError.invalidSave("Homestead resources cannot be negative.")
        }
        for (_, nodeTier) in save.homestead.nodeTiers where nodeTier < 0 {
            throw PlayerSavePersistenceError.invalidSave("Homestead node tiers cannot be negative.")
        }
        // Progressions are healed by sanitizeProgressions (level >= 1, XP clamped,
        // requiredXP recomputed), so validate skips the redundant sub-check; the
        // DEBUG assert in sanitizeAndValidate guards the post-sanitize invariant.
        try validateEncodedAffixPowers(save.inventory)
    }

    static func sanitizeLabyrinth(
        _ labyrinth: PlayerLabyrinthState,
        eligibleRecruitEventIDs: [String] = [],
        eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> PlayerLabyrinthState {
        LabyrinthSanitizer.sanitize(labyrinth, eligibleRecruitEventIDs: eligibleRecruitEventIDs, eligibleRewards: eligibleRewards)
    }
}

private func validateEncodedAffixPowers(_ inventory: PlayerInventoryState) throws {
    for item in inventory.items {
        guard let powers = item.affixPowers else { continue }
        do {
            _ = try ItemAffixPowerCoding.encode(powers)
        } catch {
            throw PlayerSavePersistenceError.invalidSave(
                "Inventory item \(item.id) affix powers could not be encoded.",
            )
        }
    }
}
