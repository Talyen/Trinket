import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

/// Deterministic coverage for Hero talent engine hooks (Combatant Talent System).
struct HeroTalentEngineTests {
    @Test func damageVsBleedingBonusAppliesWhenTargetIsBleeding() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBleedingBonus: 2)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(3), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 5, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func damageVsFrozenMultiplierDoublesDamage() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsFrozenMultiplier: 2)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 8)
    }

    @Test func holyDamageIgnoresEnemyBlock() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(holyIgnoresBlock: true)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 6, target: battle.roster.enemy.combatant, keyword: .holy, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 6)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant))
        #expect(block == 10)
    }

    @Test func burnDamageVsNoBlockMultiplierApplies() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(burnDamageVsNoBlockMultiplier: 2)
            ))
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 3, target: battle.roster.enemy.combatant, keyword: .burn, sourceActorID: "source")
        )
        #expect(outcome.healthLost == 6)
    }

    @Test func overhealConvertsToBlockForHealedTarget() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(overhealConvertsToBlock: true)
            )),
            dealOpeningHand: false
        )
        let hero = battle.roster.hero.combatant
        let outcome = battle.resolveHeal(HealRequest(amount: 5, target: hero, sourceActorID: hero.id))
        #expect(outcome.healthRestored == 0)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero))
        #expect(block == 5)
    }

    @Test func spendManaGrantsEqualBlock() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(spendManaGrantsEqualBlock: true)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(by: battle.roster.hero.combatant, amountSpent: 3, in: &battle)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant))
        #expect(block == 3)
    }

    @Test func freezeBuildupDoesNotDecayWhenSourceSuppresses() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeBuildupDoesNotDecay: true)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 4, 10), remainingTurns: 0, sourceActorID: "source")],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        ControlMeterEngine.decayFreezeBuildup(on: battle.roster.enemy.combatant, in: &battle)
        let meter = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .compactMap(\.effect.controlMeterValues)
            .first
        #expect(meter?.amount == 4)
    }

    @Test func enemyStunExtraActionSkipsExtendStun() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(enemyStunExtraActionSkips: 1)
            ))
        )
        let enemy = battle.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: enemy, in: battle)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold,
            keyword: .stun,
            to: enemy,
            sourceActorID: "source",
            applyFightPacing: false,
            in: &battle
        )
        #expect((battle.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 1)
    }
}
