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

    static func pickMysteryEvent<RNG: RandomNumberGenerator>(
        using randomNumberGenerator: inout RNG
    ) -> MysteryEvent {
        MysteryEventPool.pickMysteryEvent(using: &randomNumberGenerator)
    }

    static func pickEligibleMysteryEvent<RNG: RandomNumberGenerator>(
        unlockedHeroIDs: Set<String>,
        unlockedPetIDs: Set<String>,
        using randomNumberGenerator: inout RNG
    ) -> MysteryEvent {
        MysteryEventPool.pickEligibleMysteryEvent(
            unlockedHeroIDs: unlockedHeroIDs,
            unlockedPetIDs: unlockedPetIDs,
            using: &randomNumberGenerator
        )
    }

    static func combatant(forMysteryEvent event: MysteryEvent) -> Combatant? {
        guard let combatantID = event.unlockCombatantID else { return nil }
        return heroes.first { $0.id == combatantID } ?? pets.first { $0.id == combatantID }
    }
}
