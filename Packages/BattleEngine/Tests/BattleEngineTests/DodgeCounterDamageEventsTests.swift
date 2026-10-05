import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DodgeCounterDamageEventsTests {
    @Test(arguments: [false, true])
    func `Whiplash reports its damage once even when the hit Stuns`(triggersStun: Bool) throws {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(
            control: ControlTriggers(dodgeDealStunFlat: 3),
        ))
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        if triggersStun {
            battle.appendEffect(.controlMeter(.stun, 19, 20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }

        let before = battle.health(of: battle.enemy)
        let events = CombatExecutor.run { await CombatTriggerEngine.afterDodge(by: battle.hero, attackerID: battle.enemy.id, in: &battle) }

        #expect(before - battle.health(of: battle.enemy) == 3)
        let damage = events.filter { $0.kind == .abilityDamage && $0.abilityName == "Whiplash" }
        #expect(damage.count == 1)
        let hit = try #require(damage.first)
        #expect(hit.amount == 3)
        #expect(hit.keyword == .stun)
        #expect(hit.targetID == battle.enemy.id)
        #expect(events.count(where: { $0.effectKind == .controlTriggered }) == (triggersStun ? 1 : 0))
    }
}
