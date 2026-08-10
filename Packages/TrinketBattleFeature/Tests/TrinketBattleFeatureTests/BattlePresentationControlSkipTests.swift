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

    @Test func ignoresPartyControlStatusLingerForHandAndBorder() {
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
            dealOpeningHand: false
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.ownerControlSkipKeywords.isEmpty)
        #expect(snapshot.hero.borderAccentKeyword == nil)
        #expect(snapshot.companion.borderAccentKeyword == nil)
        // Enemy linger still accents so Shatter/Dazed feedback stays readable.
        #expect(snapshot.enemy.borderAccentKeyword == .stun)
    }

    @Test func projectsPartyBorderAccentWhileAwaitingActionSkip() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ],
            dealOpeningHand: false
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.ownerControlSkipKeywords[.hero] == .stun)
        #expect(snapshot.hero.borderAccentKeyword == .stun)
    }

    @Test func projectsShadowstepBuffAuraForEitherFlag() {
        let doubleOnly = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0),
            ],
            dealOpeningHand: false
        )
        let evadeOnly = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeCompanionEffects: [
                ActiveEffect(id: 2, effect: .evadeNextHit, remainingTurns: 0),
            ],
            dealOpeningHand: false
        )
        let doubleSnapshot = BattlePresentationSnapshot(configurationID: UUID(), state: doubleOnly)
        let evadeSnapshot = BattlePresentationSnapshot(configurationID: UUID(), state: evadeOnly)

        #expect(doubleSnapshot.hero.buffAuraKind == .shadowstep)
        #expect(doubleSnapshot.companion.buffAuraKind == nil)
        #expect(evadeSnapshot.companion.buffAuraKind == .shadowstep)
        #expect(evadeSnapshot.hero.buffAuraKind == nil)
    }

    @Test func shadowstepAuraCoexistsWithDeathsDoorBorderAccent() {
        let state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0),
                ActiveEffect(id: 2, effect: .evadeNextHit, remainingTurns: 0),
                ActiveEffect(id: 3, effect: .deathsDoor, remainingTurns: 4),
            ],
            dealOpeningHand: false
        )
        let snapshot = BattlePresentationSnapshot(configurationID: UUID(), state: state)

        #expect(snapshot.hero.borderAccentKeyword == .deathsDoor)
        #expect(snapshot.hero.buffAuraKind == .shadowstep)
    }
}
