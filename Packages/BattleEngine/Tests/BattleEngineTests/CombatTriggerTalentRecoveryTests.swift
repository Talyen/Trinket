import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatTriggerTalentRecoveryTests {
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

    @Test func overhealConversionIgnoresTargetWisdom() {
        let wiseHero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            maxHealth: 20,
            primaryStats: PrimaryStats(wisdom: 25)
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: wiseHero,
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(overhealConvertsToBlock: true)
            )),
            dealOpeningHand: false
        )
        let healed = battle.roster.hero.combatant
        let outcome = battle.resolveHeal(HealRequest(amount: 3, target: healed, sourceActorID: healed.id))
        #expect(outcome.healthRestored == 0)
        let block = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: healed))
        #expect(block == 3)
    }

    @Test func weakenSoulReducesEnemyStrengthOnLeech() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    onLeechReduceEnemyStrength: 1,
                    onLeechReduceEnemyStrengthTurns: 2
                )
            )),
            dealOpeningHand: false
        )
        let enemy = battle.roster.enemy.combatant
        _ = CombatTriggerEngine.afterLeech(
            by: battle.roster.companion.combatant,
            target: enemy,
            in: &battle
        )
        let effectiveStrength = battle.roster.runtime(for: enemy)?.primaryStats.strength ?? 0
        #expect(effectiveStrength < enemy.primaryStats.strength)
    }

    @Test func massCleanseDoesNotTreatCompanionDebuffsAsOriginalKeyword() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 2)],
            activeCompanionEffects: [ActiveEffect(id: 2, effect: .burn(3), remainingTurns: 2)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(
                    cleanseAffectsBothHeroAndCompanion: true,
                    onCleansePoisonDealDamagePerStack: 10
                )
            )),
            dealOpeningHand: false
        )
        let events = CombatTriggerEngine.performRandomCleanses(
            source: battle.roster.hero.combatant,
            target: battle.roster.hero.combatant,
            count: 1,
            abilityName: "Mass Cleanse",
            in: &battle
        )
        let companionDebuffs = battle.roster.activeEffects(for: battle.roster.companion.combatant)
            .filter(\.effect.isRemovableDebuff)
        #expect(companionDebuffs.isEmpty)
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 90)
        #expect(events.contains { $0.keyword == .poison && $0.effectKind == .cleanseApplied })
        #expect(events.contains { $0.keyword == .burn && $0.effectKind == .cleanseApplied })
    }

    @Test func autoCleanseUsesLivingAlliesOnly() {
        func poisonCount(on combatant: Combatant, in battle: BattleState) -> Int {
            battle.roster.activeEffects(for: combatant).count { $0.effect.keyword == .poison }
        }

        var heroOnly = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 2)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(autoCleanseTeamPerTurn: 1)
            )),
            dealOpeningHand: false
        )
        heroOnly.roster.mutateRuntime(for: heroOnly.roster.companion.combatant) { $0.currentHealth = 0 }
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &heroOnly)
        #expect(poisonCount(on: heroOnly.roster.hero.combatant, in: heroOnly) == 0)

        var deadCompanionAura = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 2)],
            companionModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(autoCleanseTeamPerTurn: 1)
            )),
            dealOpeningHand: false
        )
        deadCompanionAura.roster.mutateRuntime(for: deadCompanionAura.roster.companion.combatant) {
            $0.currentHealth = 0
        }
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &deadCompanionAura)
        #expect(poisonCount(on: deadCompanionAura.roster.hero.combatant, in: deadCompanionAura) == 1)
    }

    @Test func consecrationCleanseGrantsSpellbreakShield() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 2)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(holyDamageCleanseCount: 1, cleanseBlockPerStack: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterHolyDamageDealt(
            to: battle.roster.enemy.combatant,
            source: battle.roster.hero.combatant,
            in: &battle
        )
        #expect(
            DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant)) == 2
        )
        #expect(!battle.roster.activeEffects(for: battle.roster.hero.combatant).contains { $0.effect.keyword == .poison })
    }

    @Test func autoCleanseGrantsSpellbreakShield() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 2)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(cleanseBlockPerStack: 3, autoCleanseTeamPerTurn: 1)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(
            DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant)) == 3
        )
    }

    @Test func arcaneCleansingGrantsSpellbreakShield() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 2)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(spendManaThresholdCleanseCount: 1),
                cleanse: CleanseTriggers(cleanseBlockPerStack: 4)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: battle.roster.hero.combatant,
            amountSpent: 1,
            in: &battle
        )
        #expect(
            DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant)) == 4
        )
    }

    @Test func overhealConvertsToMaxHealthBeforeBlock() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealConvertsToBlock: true,
                    overhealConvertsToMaxHealth: true,
                    overhealConvertsToMaxHealthCap: 10
                )
            )),
            dealOpeningHand: false
        )
        let hero = battle.roster.hero.combatant
        _ = battle.resolveHeal(HealRequest(amount: 5, target: hero, sourceActorID: hero.id))
        #expect(battle.roster.runtime(for: hero)?.talentMaxHealthBonus == 5)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: hero)) == 0)
    }

    @Test func faeFortuneHealsTheCleanserNotTheCleanseTarget() throws {
        let cleanseCompanion = Ability(
            id: "cleanse-companion",
            name: "Cleanse Companion",
            tier: .basic,
            targetedEffects: [TargetedEffect(.cleanse(.poison), target: .companion)]
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [cleanseCompanion],
            heroMaxHealth: 20,
            companionMaxHealth: 20,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(cleanseSelfHeal: 1)
            )),
            dealOpeningHand: true
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.currentHealth = 10 }
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
            for: battle.roster.companion.combatant
        )
        _ = try BattleTestFixtures.playCardNamed("Cleanse Companion", owner: .hero, on: &battle)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 11)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 10)
    }

    @Test func pantherLeechOverhealCapsAtFour() {
        let pantherProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            attack: AttackTriggers(leechOverhealDamageBonus: 1)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: pantherProfile,
            dealOpeningHand: false
        )
        for _ in 0 ..< 10 {
            _ = HealingEngine.resolveHeal(
                HealRequest(amount: 5, target: battle.roster.companion.combatant, sourceActorID: battle.roster.companion.id, logAs: .leech),
                in: &battle
            )
        }
        let runtime = battle.roster.runtime(for: battle.roster.companion.combatant)
        #expect(runtime?.talentLeechOverhealDamageBonus == 4)
        #expect(runtime?.permanentDamageBonus == 4)
    }

    @Test func bearVitalArmorCapsAtTenMaxHealthAndTracksCumulatively() {
        let bearProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(blockGainedMaxHealthEvery: 5)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: bearProfile,
            dealOpeningHand: false
        )
        _ = EffectHandlersTestSupport.dispatch(
            .shield(.block, 3),
            ability: .block,
            source: battle.roster.companion.combatant,
            target: battle.roster.companion.combatant,
            battle: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talentMaxHealthBonus == 0)
        _ = EffectHandlersTestSupport.dispatch(
            .shield(.block, 3),
            ability: .block,
            source: battle.roster.companion.combatant,
            target: battle.roster.companion.combatant,
            battle: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talentMaxHealthBonus == 1)

        _ = EffectHandlersTestSupport.dispatch(
            .shield(.block, 100),
            ability: .block,
            source: battle.roster.companion.combatant,
            target: battle.roster.companion.combatant,
            battle: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talentMaxHealthBonus == 10)
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
                revival: RevivalTriggers(deathsDoorExpiredHealFlat: 6)
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
        #expect(
            battle.talentActionGuardByActorID[
                TalentActionGuardKey(kind: .endlessLegion, actorID: battle.roster.companion.id)
            ] != nil
        )
    }

    @Test func vitalInfusionOverhealCapsPerEventOnHealedAlly() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    overhealConvertsToMaxHealth: true,
                    overhealConvertsToMaxHealthCap: 5,
                    overhealConvertsToMaxHealthPerEvent: 1
                )
            )),
            dealOpeningHand: false
        )
        let hero = battle.roster.hero.combatant
        _ = battle.resolveHeal(
            HealRequest(amount: 8, target: hero, sourceActorID: battle.roster.companion.id)
        )
        #expect(battle.roster.maxHealth(for: hero) == 21)
        #expect(battle.roster.health(for: hero) == 21)
    }
}
