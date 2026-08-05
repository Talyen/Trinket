import Foundation
import Testing
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

struct BattlePresentationControlSkipTests {
    @Test func projectsTriggeredStunAndFreezeForPartyOwners() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
            activeCompanionEffects: [
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0),
            ],
            dealOpeningHand: false
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.ownerControlSkipKeywords[.hero] == .stun)
        #expect(snapshot.ownerControlSkipKeywords[.companion] == .freeze)
    }

    @Test func ignoresControlBuildUpAndDeathsDoorAlone() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .deathsDoor, remainingTurns: 4),
            ],
            dealOpeningHand: false
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.ownerControlSkipKeywords.isEmpty)
        #expect(snapshot.hero.borderAccentKeyword == .deathsDoor)
    }

    @Test func projectsTriggeredControlEvenWhenDeathsDoorOutranksBorder() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .deathsDoor, remainingTurns: 4),
            ],
            dealOpeningHand: false
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.ownerControlSkipKeywords[.hero] == .freeze)
        #expect(snapshot.hero.borderAccentKeyword == .deathsDoor)
    }
}
