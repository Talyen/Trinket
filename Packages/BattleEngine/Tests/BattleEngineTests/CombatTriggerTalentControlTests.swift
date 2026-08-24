import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

/// Control and affliction injected-trigger talents: stun/freeze meters and on-hit debuff application.
struct CombatTriggerTalentControlTests {
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

    @Test func seismicRoarStunsEnemyWhenCompanionDropsBelowHalf() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentStunAllEnemies: true,
                    onceBelowHealthPercentThreshold: 0.5
                )
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(amount: 11, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(battle.roster.hasControlStatus(for: battle.roster.enemy.combatant, keyword: .stun))
    }

    @Test func paralysisStunsEnemyWithEnoughPoison() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dot: DotTriggers(poisonThresholdStunAmount: 6)
            )),
            dealOpeningHand: false
        )
        let enemy = battle.roster.enemy.combatant
        let active = ActiveEffect(
            id: 1,
            effect: .poison(8),
            remainingTurns: 0,
            sourceActorID: battle.roster.companion.id
        )
        _ = DecayingDoTHandler(keyword: .poison, kind: .poison).advanceTurn(active, on: enemy, in: &battle)
        #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
    }

    @Test func venomousSkinPoisonsAttacker() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                onHit: OnHitTriggers(onHitAttackerPoison: 1)
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(amount: 3, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        let poisoned = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .contains { $0.effect.keyword == .poison }
        #expect(poisoned)
    }

    @Test func blindingLightAppliesEvadeToTargetNotAttacker() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(holyDamageTargetMissNextAttack: true)
            ))
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
                isAttackHit: true
            )
        ))
        let enemyHasEvade = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        let heroHasEvade = battle.roster.activeEffects(for: battle.roster.hero.combatant).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }
        #expect(enemyHasEvade)
        #expect(!heroHasEvade)
    }

    @Test func pinningStrikeAndParalyticPoisonRequireLivingOwner() {
        func bleedBattle(heroAlive: Bool) -> BattleState {
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(maxHealth: 50),
                companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
                activeEnemyEffects: [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0)],
                heroModifiers: .init(triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(bleedingEnemyAttackDealDamage: 5)
                )),
                dealOpeningHand: false
            )
            if !heroAlive {
                battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 0 }
            }
            return battle
        }

        var livingPin = bleedBattle(heroAlive: true)
        _ = CombatTriggerEngine.beforeEnemyActBleedReactions(in: &livingPin)
        #expect(livingPin.roster.health(for: livingPin.roster.enemy.combatant) == 35)

        var deadPin = bleedBattle(heroAlive: false)
        _ = CombatTriggerEngine.beforeEnemyActBleedReactions(in: &deadPin)
        #expect(deadPin.roster.health(for: deadPin.roster.enemy.combatant) == 40)

        func poisonBattle(heroAlive: Bool) -> BattleState {
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(maxHealth: 50),
                companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
                activeEnemyEffects: [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
                heroModifiers: .init(triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(poisonedEnemyMissChancePercent: 1)
                )),
                dealOpeningHand: false
            )
            if !heroAlive {
                battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 0 }
            }
            return battle
        }

        var livingMiss = poisonBattle(heroAlive: true)
        #expect(CombatTriggerEngine.enemyActAvoidance(in: &livingMiss).cancelled)

        var deadMiss = poisonBattle(heroAlive: false)
        #expect(!CombatTriggerEngine.enemyActAvoidance(in: &deadMiss).cancelled)
    }

    @Test func frozenCannotBlockAuraRequiresLivingOwner() {
        func makeBattle() -> BattleState {
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(),
                companion: BattleTestFixtures.passiveCompanion(),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
                companionModifiers: .init(triggers: CombatTraitTriggers(
                    control: ControlTriggers(frozenEnemyCannotBlockOrHeal: true)
                )),
                dealOpeningHand: false
            )
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
                for: battle.roster.enemy.combatant,
                on: &battle
            )
            return battle
        }

        var livingOwner = makeBattle()
        let blocked = livingOwner.applyBlock(
            4,
            to: livingOwner.roster.enemy.combatant,
            source: livingOwner.roster.hero.combatant,
            abilityName: "Test"
        )
        #expect(blocked.isEmpty)

        var deadOwner = makeBattle()
        deadOwner.roster.mutateRuntime(for: deadOwner.roster.companion.combatant) { $0.currentHealth = 0 }
        let applied = deadOwner.applyBlock(
            4,
            to: deadOwner.roster.enemy.combatant,
            source: deadOwner.roster.hero.combatant,
            abilityName: "Test"
        )
        #expect(!applied.isEmpty)
        #expect(DefensePoolEngine.blockPoints(
            in: deadOwner.roster.activeEffects(for: deadOwner.roster.enemy.combatant)
        ) > 0)
    }

    @Test func hexingRuneAppliesAfflictionOnlyWhenHeroSpendsMana() {
        func enemyIsAfflicted(_ battle: BattleState) -> Bool {
            battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains {
                $0.effect.keyword == .bleed || $0.effect.keyword == .burn || $0.effect.keyword == .poison
            }
        }

        var companionSpend = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onHeroSpendManaApplyRandomAffliction: true)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: companionSpend.roster.companion.combatant,
            amountSpent: 2,
            in: &companionSpend
        )
        #expect(!enemyIsAfflicted(companionSpend))

        var heroSpend = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onHeroSpendManaApplyRandomAffliction: true)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: heroSpend.roster.hero.combatant,
            amountSpent: 2,
            in: &heroSpend
        )
        #expect(enemyIsAfflicted(heroSpend))
    }

    @Test func spitPoisonAppliesFromCompanionWhenHeroAttacksPoisonedEnemy() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(onHeroAttackPoisonedEnemyApplyPoison: 1)
            )),
            dealOpeningHand: false
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: true,
                    applyDodge: false,
                    isAttackHit: true
                )
            )
        )
        let poisons = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .filter { $0.effect.keyword == .poison }
        #expect(poisons.contains { $0.sourceActorID == battle.roster.companion.id })
    }

    // swiftlint:disable:next function_body_length
    @Test func harvestEssenceIgnoresDoTAndRetaliation() {
        let harvest = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(onAnyHealthLossGainBlock: 1)
        ))
        var dotBattle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false
        )
        _ = dotBattle.applyDecayingDoT(
            keyword: .poison,
            potency: 3,
            to: dotBattle.roster.enemy.combatant,
            sourceActorID: dotBattle.roster.hero.id,
            dealImmediateDamage: true
        )
        #expect(DefensePoolEngine.blockPoints(
            in: dotBattle.roster.activeEffects(for: dotBattle.roster.hero.combatant)
        ) == 0)

        var hitBattle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false
        )
        _ = hitBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: hitBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: hitBattle.roster.hero.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isAttackHit: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(
            in: hitBattle.roster.activeEffects(for: hitBattle.roster.hero.combatant)
        ) == 1)

        var retaliation = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false
        )
        _ = retaliation.resolveDamage(
            DamageRequest(
                amount: 3,
                target: retaliation.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: retaliation.roster.hero.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isRetaliation: true,
                    isAttackHit: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(
            in: retaliation.roster.activeEffects(for: retaliation.roster.hero.combatant)
        ) == 0)
    }
}
