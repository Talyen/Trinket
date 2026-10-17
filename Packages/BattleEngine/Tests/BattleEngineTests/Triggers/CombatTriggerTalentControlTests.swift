import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatTriggerTalentControlTests {
    @Test func `freeze buildup does not decay`() {
        var battle = BattleTestFixtures.makePipelineContext()
        battle.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 4, 10), remainingTurns: 0, sourceActorID: "source")],
            for: battle.roster.enemy.combatant,
        )
        _ = battle.endTurn()
        let meter = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .compactMap(\.effect.controlMeterValues)
            .first
        #expect(meter?.amount == 4)
    }

    @Test func `seismic roar stuns enemy when companion drops below half`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .withTriggers {
                $0.onceBelowHealthPercentStunAllEnemies = true
                $0.onceBelowHealthPercentThreshold = 0.5
            },
            dealOpeningHand: false,
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveTestDamage(11, to: companion, keyword: .physical, sourceActorID: "enemy")
        #expect(battle.roster.hasControlStatus(for: battle.roster.enemy.combatant, keyword: .stun))
    }

    @Test(arguments: [(1.0, UInt64(1772), true), (0.0, 1772, true), (0.4, 0, true), (0.4, 1, false)])
    func `paralysis rolls its chance on a living poison tick`(chance: Double, seed: UInt64, stunned: Bool) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .withTriggers {
                $0.poisonStunChancePercent = chance
                $0.poisonThresholdStunAmount = 6
            },
            dealOpeningHand: false,
        )
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        battle.insertEffect(.poison(8), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 0)
        let active = try #require(battle.activeEffects(of: battle.enemy).first)
        CombatExecutor.run { await EffectHandlers.advanceTurn(active, on: battle.enemy, in: &battle) }
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun) == stunned)
    }

    @Test func `blinding light stores the strongest reduction from resolved holy hits`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.blindingLight = true
            }, appliesFightPacing: false,
        )
        for amount in [6, 2, 4] {
            _ = battle.resolveTestDamage(
                amount,
                keyword: .holy,
                options: DamageOperation.attack(scaling: .flat, accuracy: .unavoidable),
            )
            #expect(battle.roster.combatant(for: battle.enemy.id)?.talents.history.blindingReduction == 3)
        }
        #expect(!battle.roster.activeEffects(for: battle.enemy).contains { $0.effect == .evadeNextHit })
    }

    @Test(arguments: [false, true])
    func `pinning strike and paralytic poison require living owner`(heroAlive: Bool) {
        var pin = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
            heroModifiers: .withTriggers { $0.bleedingEnemyAttackDealDamage = 5 },
            dealOpeningHand: false,
        )
        var miss = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
            heroModifiers: .withTriggers { $0.poisonedEnemyMissChancePercent = 1 },
            dealOpeningHand: false,
        )
        if !heroAlive {
            pin.roster.hero.currentHealth = 0
            miss.roster.hero.currentHealth = 0
        }
        CombatExecutor.run { await CombatTriggerEngine.beforeEnemyAttackBleedReactions(in: &pin) }
        #expect(pin.health(of: pin.enemy) == (heroAlive ? 35 : 40))
        #expect(CombatExecutor.run { await CombatTriggerEngine.enemyAttackAvoidance(in: &miss) } == heroAlive)
    }

    @Test(arguments: [false, true])
    func `frozen cannot block aura requires living owner`(ownerAlive: Bool) {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            companionModifiers: .withTriggers { $0.frozenEnemyCannotBlockOrHeal = true },
            dealOpeningHand: false,
        )
        if !ownerAlive {
            battle.roster.companion.currentHealth = 0
        }
        let events = battle.recordingEvents { battle in
            battle.applyBlockGain(4, to: battle.enemy, source: battle.hero, abilityName: "Test")
        }
        #expect(events.isEmpty == ownerAlive)
        #expect((DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) > 0) == !ownerAlive)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `hexing rune applies affliction only when hero spends mana`(owner: BattleParticipant) {
        let profile = CombatModifierProfile.withTriggers { $0.onHeroSpendManaApplyRandomAffliction = true }
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero,
            dealOpeningHand: false,
        )
        let payer = battle.roster[owner].combatant
        CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(
            ManaPayment(payer: payer, balanceBefore: battle.mana(of: payer) + 2, balanceAfter: battle.mana(of: payer)),
            in: &battle,
        ) }
        let afflicted = battle.activeEffects(of: battle.enemy).contains {
            [.bleed, .burn, .poison].contains($0.effect.keyword)
        }
        #expect(afflicted == (owner == .hero))
        if owner == .hero {
            #expect(battle.health(of: battle.enemy) == 99)
        }
    }

    @Test func `spit poison applies from companion when hero attacks poisoned enemy`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .withTriggers { $0.onHeroAttackPoisonedEnemyApplyPoison = 1 },
            dealOpeningHand: false,
        )
        battle.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2, sourceActorID: battle.roster.hero.id)],
            for: battle.roster.enemy.combatant,
        )
        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            5,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: context.roster.hero.id,
            options: DamageOperation.attack(scaling: .items, accuracy: .unavoidable),
        ) }
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 94)
        let poisons = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .filter { $0.effect.keyword == .poison }
        #expect(poisons.count == 1)
        #expect(poisons.first?.effect.potency == 4)
        #expect(poisons.first?.sourceActorID == battle.roster.hero.id)
        #expect(outcome.events.contains {
            $0.actorID == battle.roster.companion.id && $0.keyword == .poison && $0.amount == 1
        })
    }

    @Test(arguments: [DamageOperation.periodic, .attack(scaling: .flat, accuracy: .unavoidable),
                      .reaction(cause: .talent, scaling: .flat, accuracy: .unavoidable)])
    func `harvest essence ignores do T and retaliation`(operation: DamageOperation) {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: .withTriggers { $0.onAnyHealthLossGainBlock = 1 },
            dealOpeningHand: false,
        )
        if operation.isPeriodic {
            battle.applyDecayingDoT(
                keyword: .poison, potency: 3, to: battle.enemy, sourceActorID: battle.hero.id, application: .ability,
            )
        } else {
            _ = battle.resolveTestDamage(3, options: operation)
        }
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (operation.isAttackHit ? 1 : 0))
    }
}
