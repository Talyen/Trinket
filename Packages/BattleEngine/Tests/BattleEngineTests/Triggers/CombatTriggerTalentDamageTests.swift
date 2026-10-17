import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct CombatTriggerTalentDamageTests {
    @Test(arguments: [9, 10, 11])
    func `high altitude only adds dodge above half health`(health: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 20,
            companionModifiers: .withTriggers { $0.dodgeChanceAboveHalfHealthBonus = 0.15 },
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = health }
        let hit = DamageResolutionState(
            amount: 1, combatant: battle.companion, sourceActorID: battle.enemy.id,
            damageKeyword: .physical, options: .attack(),
        )
        #expect(DamagePipeline.dodgeChance(for: hit, in: battle) == (health > 10 ? 0.25 : 0.10))
    }

    @Test(arguments: [
        (
            CombatTraitTriggers { $0.damageVsBleedingBonus = 3 },
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
            4,
            Keyword.physical,
            7,
        ),
        (
            CombatTraitTriggers { $0.damageVsFrozenMultiplier = 2 },
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            4,
            .physical,
            8,
        ),
        (CombatTraitTriggers { $0.burnDamageVsNoBlockMultiplier = 2 }, [], 3, .burn, 6),
    ])
    func `damage bonuses honor their target status and keyword`(
        triggers: CombatTraitTriggers, effects: [ActiveEffect], amount: Int, keyword: Keyword, expected: Int,
    ) {
        var battle = BattleTestFixtures.makePipelineContext(
            targetEffects: effects, heroModifiers: .init(triggers: triggers),
        )
        let outcome = battle.resolveTestDamage(amount, to: battle.enemy, keyword: keyword, sourceActorID: "source")
        #expect(outcome.healthLost == expected)
    }

    @Test(arguments: [false, true])
    func `holy block bypass preserves block for physical followups`(piercingStarlight: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            targetEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            heroModifiers: .withTriggers {
                $0.holyIgnoresBlock = !piercingStarlight
                $0.holyIgnoresBlockAndDodge = piercingStarlight
            },
        )
        let holy = battle.resolveTestDamage(6, to: battle.enemy, keyword: .holy, sourceActorID: "source")
        #expect(holy.healthLost == 6)
        if piercingStarlight {
            let physical = battle.resolveTestDamage(4, to: battle.enemy, keyword: .physical, sourceActorID: "source")
            #expect(physical.healthLost == 0)
        }
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == (piercingStarlight ? 6 : 10))
    }

    @Test(arguments: [EnemyFaction.undead, .mortal])
    func `bane of evil doubles holy against undead`(faction: EnemyFaction) {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: .withTriggers { $0.holyDamageVsUndeadOrCorruptedMultiplier = 2 },
            enemyFaction: faction, dealOpeningHand: false,
        )
        let outcome = battle.resolveTestDamage(4, keyword: .holy, options: .effect(scaling: .items, accuracy: .unavoidable))
        #expect(outcome.healthLost == (faction == .undead ? 8 : 4))
    }

    @Test func `stalker precision caps crit multiplier`() {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            companionModifiers: .withTriggers { $0.critMultiplierPerDodge = 0.5 },
            dealOpeningHand: false,
        )
        let companion = battle.roster.companion.combatant
        for _ in 0 ..< 4 {
            CombatExecutor.run { await CombatTriggerEngine.afterDodge(
                by: companion,
                attackerID: battle.roster.enemy.id,
                in: &battle,
            ) }
        }
        #expect(battle.roster.runtime(for: companion)?.talents.battle.criticalMultiplierBonus == 1.0)
    }

    @Test func `nested damage beyond depth two is retaliation`() {
        let harvest = CombatModifierProfile.withTriggers { $0.onAnyHealthLossGainBlock = 1 }
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false,
        )

        _ = battle.resolveTestDamage(3, options: .attack(origin: .counterattack, scaling: .flat, accuracy: .unavoidable))
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant),
        ) == 0)
    }

    @Test func `shield scarab companion deals bonus damage to stunned enemies`() {
        let scarabProfile = CombatModifierProfile.withTriggers { $0.damageWhileTargetStunnedBonus = 4 }
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            companionModifiers: scarabProfile,
            dealOpeningHand: false,
        )
        battle.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 100, 100), remainingTurns: 1)],
            for: battle.roster.enemy.combatant,
        )
        let outcome = battle.resolveTestDamage(5, from: .companion, options: .attack(scaling: .items, accuracy: .unavoidable))
        #expect(outcome.healthLost == 9)
    }

    @Test func `keyword reactions skip retaliation holy pings`() {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: .withTriggers {
                $0.blindingLight = true
                $0.onBurnTickHolyDamage = 1
            },
            dealOpeningHand: false,
        )
        _ = battle.resolveTestDamage(1, keyword: .holy, options: .reaction(cause: .talent, scaling: .flat, accuracy: .unavoidable))
        #expect(battle.roster.combatant(for: battle.enemy.id)?.talents.history.blindingReduction ?? 0 == 0)
    }

    @Test(arguments: [false, true])
    func `afflicted damage auras stack additively`(heroHasAura: Bool) {
        func aura(named name: String) -> CombatModifierProfile {
            .init(
                triggers: CombatTraitTriggers { $0.damageVsBurningMultiplier = 1.25 },
                triggerAbilityNames: [.damageVsBurningMultiplier: name],
            )
        }
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            heroModifiers: heroHasAura ? aura(named: "Damnation") : .zero,
            companionModifiers: aura(named: "Intense Heat"), dealOpeningHand: false,
        )
        let hit = battle.recordingResult { context in context.resolveTestDamage(
            20,
            options: .effect(scaling: .items, accuracy: .unavoidable),
        ) }
        #expect(hit.value.healthLost == (heroHasAura ? 30 : 25))
        #expect(hit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })
        if heroHasAura {
            #expect(hit.events.contains { $0.abilityName == "Damnation" && $0.kind == .ability })
        }
    }

    @Test func `prey on the weak uses hero talent on companion hits`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .withTriggers { $0.companionDamageVsPoisonedBonus = 2 },
            dealOpeningHand: false,
        )
        battle.seedActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: battle.roster.enemy.combatant)
        let outcome = battle.resolveTestDamage(5, from: .companion, options: .effect(scaling: .items, accuracy: .unavoidable))
        #expect(outcome.healthLost == 7)
    }

    @Test func `radiant health buffs hero hits while companion is full health`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .withTriggers { $0.partyDamageBonusWhileCompanionFullHealth = 2 },
            dealOpeningHand: false,
        )
        let outcome = battle.resolveTestDamage(5, options: .effect(scaling: .items, accuracy: .unavoidable))
        #expect(outcome.healthLost == 7)
    }
}

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [(false, true, 8), (true, true, 5), (false, false, 5), (true, false, 5)])
    func `enrage boosts only party attacks`(enemySource: Bool, attackHit: Bool, expectedDamage: Int) {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .withTriggers {
                $0.partyAllStatsBonusBelowHealthThreshold = 0.5
                $0.partyAllStatsBonusBelowHealthAmount = 3
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 9 }
        let sourceID = enemySource ? battle.enemy.id : battle.hero.id
        let target = enemySource ? battle.hero : battle.enemy
        let request = attackHit ? DamageRequest(
            amount: 5,
            target: target,
            keyword: .physical,
            sourceActorID: sourceID,
            options: DamageOperation.attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) : DamageRequest.doTTick(amount: 5, target: target, keyword: .burn, sourceActorID: sourceID)
        let outcome = battle.resolveDamage(request)
        #expect(outcome.healthLost == expectedDamage)
    }

    @Test func `unbroken vow does not give enemies block or dodge ignore`() {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: .withTriggers { $0.unbrokenVow = true },
        )
        battle.seedActiveEffects([ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)], for: battle.roster.enemy.combatant)
        battle.seedActiveEffects(
            [
                ActiveEffect(id: 2, effect: .shield(.block, 10), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .evadeNextHit, remainingTurns: 0),
            ],
            for: battle.roster.hero.combatant,
        )
        let dodgedOutcome = battle.resolveTestDamage(6, to: battle.roster.hero.combatant, keyword: .holy, sourceActorID: "target")
        #expect(dodgedOutcome.healthLost == 0)
        #expect(dodgedOutcome.isDodged)

        battle.seedActiveEffects([ActiveEffect(id: 4, effect: .shield(.block, 10), remainingTurns: 0)], for: battle.roster.hero.combatant)
        let blockedOutcome = battle.resolveTestDamage(6, to: battle.roster.hero.combatant, keyword: .holy, sourceActorID: "target")
        #expect(blockedOutcome.healthLost == 0)
        #expect(!blockedOutcome.isDodged)
        let heroBlock = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant))
        #expect(heroBlock == 4)
    }

    @Test func `damage cap applies to periodic hits`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .withTriggers { $0.maxDamagePerHitCap = 12 },
        )
        let outcome = battle.resolveDamage(
            DamageRequest.doTTick(amount: 20, target: battle.roster.hero.combatant, keyword: .burn, sourceActorID: "target"),
        )
        #expect(outcome.healthLost == 12)
    }
}
