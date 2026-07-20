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
        MysteryEventPool.event(matching: id)
    }

    static func recruitEvent(matching id: String) -> MysteryEvent? {
        RecruitEventPool.event(matching: id)
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

    static func resolveRecruitEncounter(
        configuredEventID: String?,
        encounterID: String,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> RecruitEncounterResolution {
        let eligible = RecruitEventPool.eligible(
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        if let configuredEventID,
           let configured = RecruitEventPool.event(matching: configuredEventID),
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
        guard let configuredEventID = stage.encounter.recruitEventID else { return stage }
        let resolution = resolveRecruitEncounter(
            configuredEventID: configuredEventID,
            encounterID: stage.id,
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs
        )
        return Stage(
            id: stage.id,
            chapterID: stage.chapterID,
            chapterNumber: stage.chapterNumber,
            stageNumber: stage.stageNumber,
            flavorText: stage.flavorText,
            encounter: resolution.stageEncounter,
            rewards: stage.rewards
        )
    }

    static func combatant(forMysteryEvent event: MysteryEvent) -> Combatant? {
        guard let combatantID = event.unlockCombatantID else { return nil }
        return heroes.first { $0.id == combatantID } ?? companions.first { $0.id == combatantID }
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
