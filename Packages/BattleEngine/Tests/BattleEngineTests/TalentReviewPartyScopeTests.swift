import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct TalentReviewPartyScopeTests {
    @Test func blockPerTurnDoesNotRequireDeathsDoor() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(blockPerTurn: 2),
                revival: RevivalTriggers(guaranteedCritWhileOnDeathsDoor: true)
            )),
            dealOpeningHand: false
        )
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        ) == 2)
    }

    @Test func purifyingAuraOnCompanionAcceleratesHeroDebuffs() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 40),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0)],
            companionModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(partyDebuffDurationHalved: true)
            )),
            dealOpeningHand: false
        )
        let healthBefore = battle.roster.health(for: battle.roster.hero.combatant)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        let remaining = battle.roster.activeEffects(for: battle.roster.hero.combatant)
            .compactMap(\.effect.potency)
            .first
        #expect(remaining == 2)
        let lost = healthBefore - battle.roster.health(for: battle.roster.hero.combatant)
        #expect(lost == Effect.poison(4).potencyAfterTurn())
    }

    @Test func endlessLegionRestoresHealthWhenDeathsDoorExpires() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                revival: RevivalTriggers(onEnemyDefeatReviveSelfHealth: 6)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.currentHealth = 1 }
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .deathsDoor, remainingTurns: 1)],
            for: battle.roster.companion.combatant,
            on: &battle
        )
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 6)
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.hasTriggeredEndlessLegion == true)
    }

    @Test func keywordReactionsSkipRetaliationHolyPings() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(holyDamageTargetMissNextAttack: true),
                dot: DotTriggers(onBurnTickHolyDamage: 1)
            )),
            dealOpeningHand: false
        )
        _ = battle.resolveDamage(DamageRequest(
            amount: 1,
            target: battle.roster.enemy.combatant,
            keyword: .holy,
            sourceActorID: battle.roster.hero.id,
            options: DamageOptions(
                applyStatBonus: false,
                applyItemBonus: false,
                applyDodge: false,
                isRetaliation: true,
                isAttackHit: false
            )
        ))
        let hasEvade = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        #expect(!hasEvade)
    }

    @Test func afflictedDamageAuraUsesStrongestPartyCopy() {
        var stacked = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
            )),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
            )),
            dealOpeningHand: false
        )
        let stackedHit = stacked.resolveDamage(DamageRequest(
            amount: 20,
            target: stacked.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: stacked.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false)
        ))
        #expect(stackedHit.healthLost == 25)

        var companionAura = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            companionModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
            )),
            dealOpeningHand: false
        )
        let auraHit = companionAura.resolveDamage(DamageRequest(
            amount: 20,
            target: companionAura.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: companionAura.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false)
        ))
        #expect(auraHit.healthLost == 25)
    }
}
