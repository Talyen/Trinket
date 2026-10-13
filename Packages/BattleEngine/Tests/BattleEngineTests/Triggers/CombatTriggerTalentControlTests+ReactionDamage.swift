import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension CombatTriggerTalentControlTests {
    @Test func `poisonous dash deals damage and attaches dot on dodge`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers.configured { $0.onDodgeApplyPoisonOrBleed = 2 }),
            dealOpeningHand: false,
        )
        _ = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
            by: battle.roster.hero.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle,
        ) }
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 98)
        let effects = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
        #expect(effects.contains { $0.effect.keyword == Keyword.poison || $0.effect.keyword == Keyword.bleed })
    }

    @Test func `stun flare deals burn damage on holy attack`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers.configured { $0.holyAttackApplyBurnAndStunBuildup = 2 }),
            dealOpeningHand: false,
        )
        _ = battle.resolveTestDamage(
            5,
            to: battle.roster.enemy.combatant,
            keyword: .holy,
            sourceActorID: battle.roster.hero.id,
            options: DamageOperation.attack(scaling: .flat, accuracy: .unavoidable),
        )
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 93)
        let burns = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .filter { $0.effect.keyword == Keyword.burn }
        #expect(!burns.isEmpty)
    }

    @Test func `solar brand deals burn damage when enemy is stunned`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers.configured { $0.onStunEnemyApplyBurn = 2 }),
            dealOpeningHand: false,
        )
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle),
            keyword: .stun,
            to: battle.enemy,
            sourceActorID: battle.hero.id,
            applyFightPacing: false,
            in: &battle,
        ) }
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 98)
        let burns = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .filter { $0.effect.keyword == Keyword.burn }
        #expect(!burns.isEmpty)
    }
}
