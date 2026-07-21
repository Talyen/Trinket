import Foundation
import TrinketCore

public extension GameContent {
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

    static func pickMysteryEvent(
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        MysteryEventPool.pickMysteryEvent(using: &randomNumberGenerator)
    }

    /// Resolves an ordinary Mystery. Recruit events are intentionally excluded.
    static func resolveMysteryEncounterEvent(
        authored: MysteryEvent?,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        authored ?? pickMysteryEvent(using: &randomNumberGenerator)
    }

    /// Non-boss enemies eligible for journey `randomBattle` stages.
    static var nonBossEnemies: [Enemy] {
        enemies.filter { !$0.isBoss }
    }

    static func pickRandomNonBossEnemyID(forStageID stageID: String) -> String? {
        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: stableSeed(for: "random-battle-\(stageID)")
        )
        return nonBossEnemies
            .map(\.id)
            .sorted()
            .randomElement(using: &randomNumberGenerator)
    }

    static func resolveRecruitEncounter(
        configuredEventID: String?,
        encounterID: String,
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
            seed: stableSeed(for: "recruit-resolution-\(encounterID)")
        )
        if let recruit = eligible.sorted(by: { $0.id < $1.id })
            .randomElement(using: &randomNumberGenerator) {
            return .recruit(recruit)
        }
        return .mystery(pickMysteryEvent(using: &randomNumberGenerator))
    }

    static func resolveRecruitStage(
        _ stage: Stage,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> Stage {
        guard case .recruit = stage.encounter else { return stage }
        let resolution = resolveRecruitEncounter(
            configuredEventID: stage.encounter.recruitEventID,
            encounterID: stage.id,
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
            "pawprint.fill"
        case .hero, .enemy:
            "person.2.fill"
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
