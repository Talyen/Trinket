import Foundation
import TrinketCore

public extension GameContent {
    static func themedTrinketIDs(forMysteryChoiceID choiceID: String) -> Set<String>? {
        let mapping: [String: Set<String>] = [
            "take-the-charm": ["icy_heart"],
            "take-the-gold": ["lucky_clover"],
            "pick-mushrooms": ["parasitic_bloom"],
            "claim-blade": ["cutpurse_knife"],
            "search-the-crypt": ["bone_charm", "sin_eaters_lantern"],
            "take-the-quill": ["runic_quill"],
            "take-the-pages": ["tattered_pages"],
            "take-a-fragment": ["meteorite"],
            "collect-the-bones": ["bone_charm"],
            "mine-the-cliffside": ["thunderstone"],
            "take-the-salts": ["bone_charm"],
            "harvest-remedies": ["mortar_and_pestle"],
            "take-the-notes": ["tattered_pages"],
            "take-the-chimes": ["resonant_chimes"],
            "claim-censer": ["brass_censer"],
        ]
        return mapping[choiceID]
    }

    static var mysteryEvents: [MysteryEvent] {
        MysteryEventPool.all
    }

    static var recruitEvents: [MysteryEvent] {
        RecruitEventPool.all
    }

    static func mysteryEvent(matching id: String) -> MysteryEvent? {
        guard !id.isEmpty else { return nil }
        return MysteryEventPool.event(matching: id)
    }

    static func recruitEvent(matching id: String) -> MysteryEvent? {
        guard !id.isEmpty, id != StageEncounter.randomCompanionRecruitID else { return nil }
        return RecruitEventPool.event(matching: id)
    }

    static var corruptionAltarEventID: String {
        MysteryEventPool.corruptionAltarID
    }

    static func pickMysteryEvent(
        context: MysteryEventPickContext = .excludingCorruptionAltar,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        MysteryEventPool.pickMysteryEvent(context: context, using: &randomNumberGenerator)
    }

    /// Resolves an ordinary Mystery. Recruit events are intentionally excluded.
    static func resolveMysteryEncounterEvent(
        authored: MysteryEvent?,
        context: MysteryEventPickContext = .excludingCorruptionAltar,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        authored ?? pickMysteryEvent(context: context, using: &randomNumberGenerator)
    }

    /// Authored mystery or recruit for a stage, preferring an explicit forced id.
    static func authoredMysteryOrRecruitEvent(
        forcedEventID: String? = nil,
        stage: Stage
    ) -> MysteryEvent? {
        forcedEventID.flatMap {
            mysteryEvent(matching: $0) ?? recruitEvent(matching: $0)
        } ?? stage.mysteryEvent
    }

    /// Seeded journey mystery pick (stable per save + stage so map art matches the encounter).
    /// Prefer an authored / forced event, then a save-pinned id, then the seeded pool.
    static func resolveJourneyMysteryEvent(
        stageID: String,
        worldSeed: UInt64,
        authored: MysteryEvent?,
        pinnedEventID: String? = nil,
        context: MysteryEventPickContext = .excludingCorruptionAltar
    ) -> MysteryEvent {
        if let authored {
            return authored
        }
        if let pinnedEventID,
           let pinned = mysteryEvent(matching: pinnedEventID) ?? recruitEvent(matching: pinnedEventID) {
            return pinned
        }
        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: encounterSeed(worldSeed, salt: "journey-mystery-\(stageID)")
        )
        return resolveMysteryEncounterEvent(
            authored: nil,
            context: context,
            using: &randomNumberGenerator
        )
    }

    /// Shared journey resolve used by map art and encounter open.
    static func resolveJourneyMysteryEvent(
        stage: Stage,
        worldSeed: UInt64,
        forcedEventID: String? = nil,
        pinnedEventID: String? = nil,
        context: MysteryEventPickContext = .excludingCorruptionAltar
    ) -> MysteryEvent {
        resolveJourneyMysteryEvent(
            stageID: stage.id,
            worldSeed: worldSeed,
            authored: authoredMysteryOrRecruitEvent(forcedEventID: forcedEventID, stage: stage),
            pinnedEventID: pinnedEventID,
            context: context
        )
    }

    /// Seeded Labyrinth mystery pick (stable per save + node so reopen does not re-roll).
    /// Prefer a pinned `mysteryEventID` on the node when present.
    static func resolveLabyrinthMysteryEvent(
        nodeID: String,
        worldSeed: UInt64,
        forcedEventID: String?,
        pinnedEventID: String? = nil,
        context: MysteryEventPickContext = .excludingCorruptionAltar
    ) -> MysteryEvent {
        if let forcedEventID,
           let forced = mysteryEvent(matching: forcedEventID) ?? recruitEvent(matching: forcedEventID) {
            return forced
        }
        if let pinnedEventID,
           let pinned = mysteryEvent(matching: pinnedEventID) ?? recruitEvent(matching: pinnedEventID) {
            return pinned
        }
        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: encounterSeed(worldSeed, salt: "labyrinth-mystery-\(nodeID)")
        )
        return resolveMysteryEncounterEvent(
            authored: nil,
            context: context,
            using: &randomNumberGenerator
        )
    }

    /// Synthetic stage stub for Labyrinth shop / mystery / recruit node sessions.
    static func syntheticLabyrinthStage(
        nodeID: String,
        encounter: StageEncounter
    ) -> Stage {
        Stage(
            id: nodeID,
            chapterID: "labyrinth",
            chapterNumber: 0,
            stageNumber: 0,
            encounter: encounter,
            rewards: .empty
        )
    }

    /// Non-boss enemies eligible for journey `randomBattle` stages.
    static var nonBossEnemies: [Enemy] {
        enemies.filter { !$0.isBoss }
    }

    static func pickRandomNonBossEnemyID(forStageID stageID: String, worldSeed: UInt64) -> String? {
        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: encounterSeed(worldSeed, salt: "random-battle-\(stageID)")
        )
        return nonBossEnemies
            .map(\.id)
            .randomElement(using: &randomNumberGenerator)
    }

    static func resolveRecruitEncounter(
        configuredEventID: String?,
        encounterID: String,
        worldSeed: UInt64,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> RecruitEncounterResolution {
        let roleFilter: Combatant.Role? =
            configuredEventID == StageEncounter.randomCompanionRecruitID ? .companion : nil
        let eligible = RecruitEventPool.eligible(
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            role: roleFilter
        )
        let configuredID = configuredEventID.flatMap { id -> String? in
            guard !id.isEmpty, id != StageEncounter.randomCompanionRecruitID else { return nil }
            return id
        }
        if let configuredID,
           let configured = RecruitEventPool.event(matching: configuredID),
           eligible.contains(configured) {
            return .recruit(configured)
        }

        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: encounterSeed(worldSeed, salt: "recruit-resolution-\(encounterID)")
        )
        if let recruit = eligible.randomElement(using: &randomNumberGenerator) {
            return .recruit(recruit)
        }
        return .mystery(pickMysteryEvent(using: &randomNumberGenerator))
    }

    static func resolveRecruitStage(
        _ stage: Stage,
        worldSeed: UInt64,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> Stage {
        guard case .recruit = stage.encounter else { return stage }
        let resolution = resolveRecruitEncounter(
            configuredEventID: stage.encounter.recruitEventID,
            encounterID: stage.id,
            worldSeed: worldSeed,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        return Stage(
            id: stage.id,
            chapterID: stage.chapterID,
            chapterNumber: stage.chapterNumber,
            stageNumber: stage.stageNumber,
            encounter: resolution.stageEncounter,
            rewards: stage.rewards
        )
    }

    static func combatant(forMysteryEvent event: MysteryEvent) -> Combatant? {
        guard let combatantID = event.unlockCombatantID else { return nil }
        return heroes.first { $0.id == combatantID } ?? companions.first { $0.id == combatantID }
    }

    static func recruitEncounterArtReference(for role: Combatant.Role) -> EncounterArtReference? {
        let artID = role == .companion ? "mystery-recruit-companions" : "mystery-recruit-heroes"
        return ArtCatalog.encounterArtByID[artID]
    }

    static func recruitEncounterArtReference(for event: MysteryEvent) -> EncounterArtReference? {
        guard event.isRecruit, let combatant = combatant(forMysteryEvent: event) else { return nil }
        return recruitEncounterArtReference(for: combatant.role)
    }

    /// Map glyph for a configured recruit event. Uses the authored combatant role;
    /// does not run recruit resolution.
    static func recruitEncounterSymbolName(forEventID eventID: String?) -> String {
        if eventID == StageEncounter.randomCompanionRecruitID {
            return recruitEncounterSymbolName(for: .companion)
        }
        guard let eventID,
              !eventID.isEmpty,
              let event = recruitEvent(matching: eventID),
              let combatant = combatant(forMysteryEvent: event)
        else {
            return recruitEncounterSymbolName(for: .hero)
        }
        return recruitEncounterSymbolName(for: combatant.role)
    }

    static func recruitEncounterSymbolName(for role: Combatant.Role) -> String {
        switch role {
        case .companion:
            StageTypeSymbol.recruitCompanion
        case .hero, .enemy:
            StageTypeSymbol.recruitHero
        }
    }
}

public enum RecruitEncounterResolution: Equatable, Sendable {
    case recruit(MysteryEvent)
    case mystery(MysteryEvent)

    public var event: MysteryEvent {
        switch self {
        case let .recruit(event), let .mystery(event): event
        }
    }

    public var stageEncounter: StageEncounter {
        switch self {
        case let .recruit(event): .recruit(eventID: event.id)
        case let .mystery(event): .mysteryEvent(eventID: event.id)
        }
    }
}
