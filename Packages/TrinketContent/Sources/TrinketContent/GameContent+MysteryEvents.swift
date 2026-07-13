import Foundation
import TrinketCore

public extension GameContent {
    static var mysteryEvents: [MysteryEvent] {
        MysteryEventPool.all + RecruitMysteryEventPool.all
    }

    static var branchingMysteryEvents: [MysteryEvent] {
        MysteryEventPool.all
    }

    static var recruitMysteryEvents: [MysteryEvent] {
        RecruitMysteryEventPool.all
    }

    static func mysteryEvent(matching id: String) -> MysteryEvent? {
        MysteryEventPool.mysteryEvent(matching: id)
    }

    static func pickMysteryEvent(
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        MysteryEventPool.pickMysteryEvent(using: &randomNumberGenerator)
    }

    static func pickEligibleMysteryEvent(
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> MysteryEvent {
        MysteryEventPool.pickEligibleMysteryEvent(
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedCompanionIDs: unlockedCompanionIDs,
            using: &randomNumberGenerator
        )
    }

    static func combatant(forMysteryEvent event: MysteryEvent) -> Combatant? {
        guard let combatantID = event.unlockCombatantID else { return nil }
        return heroes.first { $0.id == combatantID } ?? companions.first { $0.id == combatantID }
    }
}
