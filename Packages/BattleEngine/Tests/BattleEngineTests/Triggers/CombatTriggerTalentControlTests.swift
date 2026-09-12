import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CombatTriggerTalentControlTests {
    @Test(arguments: [(Keyword.stun, "knight_stun_t4_1"), (.freeze, "bear_block_t4_1")])
    func `party block doubling does not reapply outgoing bonuses`(keyword: Keyword, talent: String) {
        var profile = CombatantTalentCatalog.profile(for: [talent])
        profile.blockGainedBonus = 3
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        DefensePoolEngine.set(5, on: battle.hero, in: &battle)
        DefensePoolEngine.set(7, on: battle.companion, in: &battle)
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle), keyword: keyword,
            to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false, in: &battle,
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 10)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == 14)
    }

    @Test func `freeze buildup does not decay`() {
        var battle = BattleTestFixtures.makePipelineContext()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 4, 10), remainingTurns: 0, sourceActorID: "source")],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        _ = BattleCardCombatEngine.endTurn(context: &battle)
        let meter = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .compactMap(\.effect.controlMeterValues)
            .first
        #expect(meter?.amount == 4)
    }

    @Test func `enemy stun extra action skips extend stun`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunExtendChancePercent: 1.0),
            )),
        )
        let enemy = battle.roster.enemy.combatant
        let threshold = ControlMeterEngine.threshold(for: enemy, in: battle)
        _ = ControlMeterEngine.applyMeterCharge(
            threshold,
            keyword: .stun,
            to: enemy,
            sourceActorID: "source",
            applyFightPacing: false,
            in: &battle,
        )
        #expect((battle.additionalControlSkipsByCombatantID[enemy.id] ?? 0) == 1)
    }

    @Test func `seismic roar stuns enemy when companion drops below half`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentStunAllEnemies: true,
                    onceBelowHealthPercentThreshold: 0.5,
                ),
            )),
            dealOpeningHand: false,
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(amount: 11, target: companion, keyword: .physical, sourceActorID: "enemy"),
        )
        #expect(battle.roster.hasControlStatus(for: battle.roster.enemy.combatant, keyword: .stun))
    }

    @Test(arguments: [(1.0, UInt64(1772), true), (0.0, 1772, true), (0.4, 0, true), (0.4, 1, false)])
    func `paralysis rolls its chance on a living poison tick`(chance: Double, seed: UInt64, stunned: Bool) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dot: DotTriggers(poisonStunChancePercent: chance, poisonThresholdStunAmount: 6),
            )),
            dealOpeningHand: false,
        )
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        battle.appendEffect(.poison(8), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 0)
        let active = try #require(battle.activeEffects(of: battle.enemy).first)
        let handler = try #require(EffectHandlers.all[.poison])
        _ = handler.advanceTurn(active, on: battle.enemy, in: &battle)
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun) == stunned)
    }

    @Test func `venomous skin poisons attacker`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(onHitAttackerPoison: 1),
            )),
            dealOpeningHand: false,
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(amount: 3, target: companion, keyword: .physical, sourceActorID: "enemy"),
        )
        let poisoned = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .contains { $0.effect.keyword == .poison }
        #expect(poisoned)
    }

    @Test func `blinding light stores the strongest reduction from resolved holy hits`() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(criticalChanceBonus: -1), mitigation: MitigationTriggers(blindingLight: true),
            )),
        )
        battle.appliesFightPacing = false
        for amount in [6, 2, 4] {
            _ = battle.resolveDamage(DamageRequest(
                amount: amount, target: battle.enemy, keyword: .holy, sourceActorID: battle.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .flat, accuracy: .unavoidable),
            ))
            #expect(battle.heroTalents.history[battle.enemy.id]?.blindingReduction == 3)
        }
        #expect(!battle.roster.activeEffects(for: battle.enemy).contains { $0.effect == .evadeNextHit })
    }

    @Test func `pinning strike and paralytic poison require living owner`() {
        func bleedBattle(heroAlive: Bool) -> BattleState {
            var battle = BattleStateTestFactory.makeBattle(
                hero: CombatantFixtures.passiveHero(maxHealth: 50),
                companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                activeEnemyEffects: [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
                heroModifiers: .init(triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(bleedingEnemyAttackDealDamage: 5),
                )),
                dealOpeningHand: false,
            )
            if !heroAlive {
                battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 0 }
            }
            return battle
        }

        var livingPin = bleedBattle(heroAlive: true)
        _ = CombatTriggerEngine.beforeEnemyAttackBleedReactions(in: &livingPin)
        #expect(livingPin.roster.health(for: livingPin.roster.enemy.combatant) == 35)

        var deadPin = bleedBattle(heroAlive: false)
        _ = CombatTriggerEngine.beforeEnemyAttackBleedReactions(in: &deadPin)
        #expect(deadPin.roster.health(for: deadPin.roster.enemy.combatant) == 40)

        func poisonBattle(heroAlive: Bool) -> BattleState {
            var battle = BattleStateTestFactory.makeBattle(
                hero: CombatantFixtures.passiveHero(maxHealth: 50),
                companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                activeEnemyEffects: [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
                heroModifiers: .init(triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(poisonedEnemyMissChancePercent: 1),
                )),
                dealOpeningHand: false,
            )
            if !heroAlive {
                battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 0 }
            }
            return battle
        }

        var livingMiss = poisonBattle(heroAlive: true)
        #expect(CombatTriggerEngine.enemyAttackAvoidance(in: &livingMiss).cancelled)

        var deadMiss = poisonBattle(heroAlive: false)
        #expect(!CombatTriggerEngine.enemyAttackAvoidance(in: &deadMiss).cancelled)
    }

    @Test func `frozen cannot block aura requires living owner`() {
        func makeBattle() -> BattleState {
            var battle = BattleStateTestFactory.makeBattle(
                hero: CombatantFixtures.passiveHero(),
                companion: CombatantFixtures.passiveCompanion(),
                enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
                companionModifiers: .init(triggers: CombatTraitTriggers(
                    control: ControlTriggers(frozenEnemyCannotBlockOrHeal: true),
                )),
                dealOpeningHand: false,
            )
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
                for: battle.roster.enemy.combatant,
                on: &battle,
            )
            return battle
        }

        var livingOwner = makeBattle()
        let blocked = livingOwner.applyBlock(
            4,
            to: livingOwner.roster.enemy.combatant,
            source: livingOwner.roster.hero.combatant,
            abilityName: "Test",
        )
        #expect(blocked.isEmpty)

        var deadOwner = makeBattle()
        deadOwner.roster.mutateRuntime(for: deadOwner.roster.companion.combatant) { $0.currentHealth = 0 }
        let applied = deadOwner.applyBlock(
            4,
            to: deadOwner.roster.enemy.combatant,
            source: deadOwner.roster.hero.combatant,
            abilityName: "Test",
        )
        #expect(!applied.isEmpty)
        #expect(DefensePoolEngine.blockPoints(
            in: deadOwner.roster.activeEffects(for: deadOwner.roster.enemy.combatant),
        ) > 0)
    }

    @Test func `hexing rune applies affliction only when hero spends mana`() {
        func enemyIsAfflicted(_ battle: BattleState) -> Bool {
            battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
                $0.effect.keyword == .bleed || $0.effect.keyword == .burn || $0.effect.keyword == .poison
            }
        }

        var companionSpend = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onHeroSpendManaApplyRandomAffliction: true),
            )),
            dealOpeningHand: false,
        )
        _ = CombatTriggerEngine.afterSpendMana(
            ManaPayment(
                payer: companionSpend.roster.companion.combatant,
                balanceBefore: companionSpend.mana(of: companionSpend.roster.companion.combatant) + 2,
                balanceAfter: companionSpend.mana(of: companionSpend.roster.companion.combatant),
            ),
            in: &companionSpend,
        )
        #expect(!enemyIsAfflicted(companionSpend))

        var heroSpend = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onHeroSpendManaApplyRandomAffliction: true),
            )),
            dealOpeningHand: false,
        )
        _ = CombatTriggerEngine.afterSpendMana(
            ManaPayment(
                payer: heroSpend.roster.hero.combatant,
                balanceBefore: heroSpend.mana(of: heroSpend.roster.hero.combatant) + 2,
                balanceAfter: heroSpend.mana(of: heroSpend.roster.hero.combatant),
            ),
            in: &heroSpend,
        )
        #expect(enemyIsAfflicted(heroSpend))
    }

    @Test func `spit poison applies from companion when hero attacks poisoned enemy`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(onHeroAttackPoisonedEnemyApplyPoison: 1),
            )),
            dealOpeningHand: false,
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle,
        )
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .items, accuracy: .unavoidable),
            ),
        )
        let poisons = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .filter { $0.effect.keyword == .poison }
        #expect(poisons.contains { $0.sourceActorID == battle.roster.companion.id })
    }

    @Test func `harvest essence ignores do T and retaliation`() {
        let harvest = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(onAnyHealthLossGainBlock: 1),
        ))
        var dotBattle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false,
        )
        _ = dotBattle.applyDecayingDoT(
            keyword: .poison,
            potency: 3,
            to: dotBattle.roster.enemy.combatant,
            sourceActorID: dotBattle.roster.hero.id,
            application: .ability,
        )
        #expect(DefensePoolEngine.blockPoints(
            in: dotBattle.roster.activeEffects(for: dotBattle.roster.hero.combatant),
        ) == 0)

        var hitBattle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false,
        )
        _ = hitBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: hitBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: hitBattle.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .flat, accuracy: .unavoidable),
            ),
        )
        #expect(DefensePoolEngine.blockPoints(
            in: hitBattle.roster.activeEffects(for: hitBattle.roster.hero.combatant),
        ) == 1)

        var retaliation = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false,
        )
        _ = retaliation.resolveDamage(
            DamageRequest(
                amount: 3,
                target: retaliation.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: retaliation.roster.hero.id,
                options: DamageOperation.reaction(cause: .talent, scaling: .flat, accuracy: .unavoidable),
            ),
        )
        #expect(DefensePoolEngine.blockPoints(
            in: retaliation.roster.activeEffects(for: retaliation.roster.hero.combatant),
        ) == 0)
    }
}
