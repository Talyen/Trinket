import Foundation
import Testing
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

struct BattlePresentationProjectionTests {
    @Test func `projects triggered stun and freeze for party combatants`() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
            activeCompanionEffects: [
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0),
            ],
            dealOpeningHand: false,
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.hero.borderAccentKeyword == .stun)
        #expect(snapshot.companion.borderAccentKeyword == .freeze)
    }

    @Test func `ignores control build up but projects deaths door`() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 4, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .deathsDoor, remainingTurns: 4),
            ],
            dealOpeningHand: false,
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.hero.borderAccentKeyword == .deathsDoor)
    }

    @Test func `ignores party control status linger for hand and border`() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            activeEnemyEffects: [
                ActiveEffect(id: 3, effect: .controlMeter(.stun, 10, 10), remainingTurns: 1),
            ],
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 1),
            ],
            activeCompanionEffects: [
                ActiveEffect(id: 2, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 1),
            ],
            dealOpeningHand: false,
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.hero.borderAccentKeyword == nil)
        #expect(snapshot.companion.borderAccentKeyword == nil)
        #expect(snapshot.enemy.borderAccentKeyword == .stun)
    }
}
