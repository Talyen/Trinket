// swiftlint:disable file_length
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

/// Injected-trigger talent mechanics (catalog round-trips live in `TalentCatalogRoundTripTests`).
struct CombatTriggerTalentTests { // swiftlint:disable:this type_body_length
    @Test func damageVsBleedingBonusAppliesWhenTargetIsBleeding() {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(damageVsBleedingBonus: 3)
            ))
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
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

    @Test func bulwarkFortressReducesHeroDamageWhileCompanionBlocked() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionBlockProtectsHeroPercent: 0.5)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            5,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        let hero = battle.roster.hero.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 10, target: hero, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(outcome.healthLost == 5)
    }

    @Test func ironhideCapsDamagePerHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(maxDamagePerHitCap: 10)
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(amount: 16, target: companion, keyword: .physical, sourceActorID: "enemy")
        )
        #expect(outcome.healthLost == 10)
    }

    @Test func counterPounceCountersWhenDodging() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgeCounterDamage: 3)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 97)
    }

    @Test func shieldBondSharesBlockToHero() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionBlockSharesToHeroPercent: 1)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            4,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        let heroBlock = DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.hero.combatant))
        #expect(heroBlock == 4)
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
        _ = DecayingDoTHandler(keyword: .poison).advanceTurn(active, on: enemy, in: &battle)
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

    @Test func prismaticSparkCanDoubleManaGain() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 6,
            companionMana: 0,
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(manaGainDoubleChancePercent: 1)
            )),
            dealOpeningHand: false
        )
        let restored = battle.restoreMana(1, to: battle.roster.companion.combatant)
        #expect(restored == 2)
    }

    @Test func blindingCarapaceDebuffsAttackerAfterBlocking() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 50),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    onBlockReduceAttackerAccuracyPercent: 25,
                    onBlockReduceAttackerAccuracyTurns: 2
                )
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            10,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        _ = battle.resolveDamage(
            DamageRequest(amount: 10, target: battle.roster.companion.combatant, keyword: .physical, sourceActorID: "enemy")
        )
        let hasDebuff = battle.roster.activeEffects(for: battle.roster.enemy.combatant).contains { active in
            if case .damageReductionPercent = active.effect {
                return true
            }
            return false
        }
        #expect(hasDebuff)
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

    @Test func goldReservesCapsBonusDamageAtFive() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            initialGold: 100,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(goldReservesDamageEvery: 10, goldReservesDamageCap: 5)
            )),
            dealOpeningHand: false
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 4,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 9)
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

    @Test func armorPierceIgnoresMitigationForLeechOnly() {
        let toughEnemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 40,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 80)
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: toughEnemy,
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(leechIgnoresMitigation: true)
            )),
            dealOpeningHand: false
        )
        let physical = battle.resolveDamage(
            DamageRequest(
                amount: 10,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        let leech = battle.resolveDamage(
            DamageRequest(
                amount: 10,
                target: battle.roster.enemy.combatant,
                keyword: .leech,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        #expect(physical.healthLost == 5)
        #expect(leech.healthLost == 10)
    }

    @Test func baneOfEvilDoublesHolyAgainstUndead() {
        let triggers = CombatTraitTriggers(
            damage: DamageTriggers(holyDamageVsUndeadOrCorruptedMultiplier: 2)
        )
        var undead = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: triggers),
            enemyFaction: .undead,
            dealOpeningHand: false
        )
        let vsUndead = undead.resolveDamage(
            DamageRequest(
                amount: 4,
                target: undead.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: undead.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        var mortal = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: triggers),
            enemyFaction: .mortal,
            dealOpeningHand: false
        )
        let vsMortal = mortal.resolveDamage(
            DamageRequest(
                amount: 4,
                target: mortal.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: mortal.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyDodge: false)
            )
        )
        #expect(vsUndead.healthLost == 8)
        #expect(vsMortal.healthLost == 4)
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

    @Test func stalkerPrecisionCapsCritMultiplier() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(critMultiplierPerDodge: 0.5)
            )),
            dealOpeningHand: false
        )
        let companion = battle.roster.companion.combatant
        for _ in 0 ..< 4 {
            _ = CombatTriggerEngine.afterDodge(
                by: companion,
                attackerID: battle.roster.enemy.id,
                in: &battle
            )
        }
        #expect(battle.roster.runtime(for: companion)?.talentCritMultiplierBonus == 1.0)
    }

    @Test func spellEchoPlaysTheFirstSkillOncePerBattle() throws {
        let poke = Ability(id: "poke", name: "Poke", tier: .skill, directDamage: 1)
        let jab = Ability(id: "jab", name: "Jab", tier: .skill, directDamage: 1)
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(firstSkillCardPlaysTwicePerBattle: true)
            )),
            dealOpeningHand: false
        )
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: poke, owner: .hero))
        battle.nextCardID += 1
        battle.hand.append(BattleCard(id: battle.nextCardID, ability: jab, owner: .hero))
        let health = { battle.roster.health(for: battle.roster.enemy.combatant) }
        let beforeFirst = health()
        _ = try BattleTestFixtures.playCardNamed("Poke", owner: .hero, on: &battle)
        let afterFirst = health()
        _ = try BattleTestFixtures.playCardNamed("Jab", owner: .hero, on: &battle)
        let afterSecond = health()
        #expect(beforeFirst - afterFirst == 2)
        #expect(afterFirst - afterSecond == 1)
        #expect(battle.skillEchoOwnersThisBattle.contains(battle.roster.hero.id))
    }

    @Test func fontOfMagicDoesNotRestoreManaWhenHealingSelf() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            maxMana: 5,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(onHealRestoreCasterMana: 1)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: hero) {
            $0.currentHealth = 10
            $0.currentMana = 0
        }
        _ = battle.resolveHeal(HealRequest(amount: 3, target: hero, sourceActorID: hero.id))
        #expect(battle.roster.runtime(for: hero)?.currentMana == 0)
    }

    @Test func nestedDamageBeyondDepthTwoIsRetaliation() {
        let harvest = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(onAnyHealthLossGainBlock: 1)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: harvest,
            dealOpeningHand: false
        )
        battle.talentReactionDepth = 2
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    isAttackHit: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant)
        ) == 0)
    }

    @Test func shieldScarabCompanionDealsBonusDamageToStunnedEnemies() {
        let scarabProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            damage: DamageTriggers(damageWhileTargetStunnedBonus: 4)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: scarabProfile,
            dealOpeningHand: false
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 100, 100), remainingTurns: 1)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 5,
            target: battle.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.companion.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false, isAttackHit: true)
        ))
        #expect(outcome.healthLost == 9) // 5 + 4 bonus
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
        // Fully healthy companion receives 10 separate 1-point leech heals
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
        // Gain 3 block, then 3 block (total 6 -> +1 Max HP)
        _ = battle.applyBlock(3, to: battle.roster.companion.combatant, source: battle.roster.companion.combatant, abilityName: "Test")
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talentMaxHealthBonus == 0)
        _ = battle.applyBlock(3, to: battle.roster.companion.combatant, source: battle.roster.companion.combatant, abilityName: "Test")
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talentMaxHealthBonus == 1)

        // Gain massive block (total 100 -> capped at +10 Max HP)
        _ = battle.applyBlock(100, to: battle.roster.companion.combatant, source: battle.roster.companion.combatant, abilityName: "Test")
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.talentMaxHealthBonus == 10)
    }

    @Test func ironhideDoesNotCapDotDamage() {
        let ironhideProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(maxDamagePerHitCap: 10)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            heroModifiers: ironhideProfile,
            dealOpeningHand: false
        )
        // Direct attack from enemy with 20 damage is capped to 10
        let attackOutcome = battle.resolveDamage(DamageRequest(
            amount: 20,
            target: battle.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.enemy.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false, isAttackHit: true)
        ))
        #expect(attackOutcome.healthLost == 10)

        // DoT tick from enemy with 20 damage is NOT capped by Ironhide
        let dotOutcome = battle.resolveDamage(DamageRequest(
            amount: 20,
            target: battle.roster.hero.combatant,
            keyword: .bleed,
            sourceActorID: battle.roster.enemy.id,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false, isAttackHit: false)
        ))
        #expect(dotOutcome.healthLost == 20)
    }

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

    @Test func afflictedDamageAurasStackAdditively() {
        var stacked = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            heroModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Damnation"]
            ),
            companionModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Intense Heat"]
            ),
            dealOpeningHand: false
        )
        let stackedHit = stacked.resolveDamage(DamageRequest(
            amount: 20,
            target: stacked.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: stacked.roster.hero.id,
            options: DamageOptions(applyStatBonus: false, applyDodge: false)
        ))
        #expect(stackedHit.healthLost == 30)
        #expect(stackedHit.events.contains { $0.abilityName == "Damnation" && $0.kind == .ability })
        #expect(stackedHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })

        var companionAura = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)],
            companionModifiers: .init(
                triggers: CombatTraitTriggers(
                    damage: DamageTriggers(damageVsBurningMultiplier: 1.25)
                ),
                triggerAbilityNames: ["damageVsBurningMultiplier": "Intense Heat"]
            ),
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
        #expect(auraHit.events.contains { $0.abilityName == "Intense Heat" && $0.kind == .ability })
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

    @Test func feintStrikeEmpowersLivingPartyNextCard() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgePartyNextCardDamageBonus: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingCardDamageBonus == 2)
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.pendingCardDamageBonus == 2)

        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) {
            $0.currentHealth = 0
            $0.pendingCardDamageBonus = 0
        }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.pendingCardDamageBonus = 0 }
        _ = CombatTriggerEngine.afterDodge(
            by: battle.roster.companion.combatant,
            attackerID: battle.roster.enemy.id,
            in: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingCardDamageBonus == 2)
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.pendingCardDamageBonus == 0)
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

    @Test func preyOnTheWeakUsesHeroTalentOnCompanionHits() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            heroModifiers: .init(triggers: CombatTraitTriggers(
                damage: DamageTriggers(companionDamageVsPoisonedBonus: 2)
            )),
            dealOpeningHand: false
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.companion.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func radiantHealthBuffsHeroHitsWhileCompanionIsFullHealth() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(partyDamageBonusWhileCompanionFullHealth: 2)
            )),
            dealOpeningHand: false
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: true, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 7)
    }

    @Test func sacrificialGuardRedirectsThroughCompanionBlock() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 8),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 30),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionFatalDamageRedirectBlock: 10)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            20,
            to: battle.roster.companion.combatant,
            source: battle.roster.companion.combatant,
            abilityName: "Test"
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 12,
                target: battle.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: battle.roster.enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 0)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 8)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 30)
        let companionBlock = DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        )
        #expect(companionBlock == 18)
    }

    @Test func manaAbsorptionGrantsCompanionBlockWhenHeroSpendsMana() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onHeroSpendManaGainBlock: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: battle.roster.hero.combatant,
            amountSpent: 3,
            in: &battle
        )
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.companion.combatant)
        ) == 2)
        #expect(DefensePoolEngine.blockPoints(
            in: battle.roster.activeEffects(for: battle.roster.hero.combatant)
        ) == 0)
    }

    @Test func aetherialFlowBuffsCompanionNextAttackWhenHeroSpendsMana() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(onHeroSpendManaCompanionNextAttackBonus: 2)
            )),
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: battle.roster.hero.combatant,
            amountSpent: 1,
            in: &battle
        )
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.pendingCardDamageBonus == 2)
        #expect(battle.roster.runtime(for: battle.roster.hero.combatant)?.pendingCardDamageBonus == 0)
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

    @Test func hagglerBoostsAllPartyGoldGain() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(partyGoldGainedPercent: 0.15)
            )),
            dealOpeningHand: false
        )
        battle.addGold(20, sourceActorID: battle.roster.hero.id)
        #expect(battle.gold == 23)
    }

    @Test func scavengersCacheSpendsGoldToAbsorbDamage() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldAbsorbsDamage: true)
            )),
            dealOpeningHand: false
        )
        battle.gold = 5
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 4,
                target: companion,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 0)
        #expect(battle.gold == 1)
    }

    @Test func scavengersCacheCapsAbsorptionAtFivePerHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldAbsorbsDamage: true)
            )),
            dealOpeningHand: false
        )
        battle.gold = 20
        let companion = battle.roster.companion.combatant
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 12,
                target: companion,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 7)
        #expect(battle.gold == 15)
    }

    @Test func campfireComfortRestoresEachAllyAtEndOfRound() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 20),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(partyRegenPerRound: 1)
            )),
            dealOpeningHand: false
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        battle.roster.mutateRuntime(for: battle.roster.companion.combatant) { $0.currentHealth = 10 }
        _ = CombatTriggerEngine.atPlayerEndTurn(in: &battle)
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 11)
        #expect(battle.roster.health(for: battle.roster.companion.combatant) == 11)
    }

    @Test func flawlessBountyDoublesGoldWhileCompanionAtFullHealth() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldDoubledWhileFullHealth: true)
            )),
            dealOpeningHand: false
        )
        battle.addGold(10, sourceActorID: battle.roster.hero.id)
        #expect(battle.gold == 20)

        var woundedBattle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldDoubledWhileFullHealth: true)
            )),
            dealOpeningHand: false
        )
        woundedBattle.roster.mutateRuntime(for: woundedBattle.roster.companion.combatant) { $0.currentHealth = 10 }
        woundedBattle.addGold(10, sourceActorID: woundedBattle.roster.hero.id)
        #expect(woundedBattle.gold == 10)
    }

    @Test func treasureHoardGrantsPartyCritChanceWhileCarryingEnoughGold() {
        func makeBattle(gold: Int) -> BattleState {
            // Deterministic seed plus a large bonus: with 50+ Gold the capped roll
            // succeeds; without it the base contested chance stays below the threshold.
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(),
                companion: BattleTestFixtures.passiveCompanion(),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
                companionModifiers: .init(triggers: CombatTraitTriggers(
                    damage: DamageTriggers(
                        partyCritChanceWhileGoldAbove: 50,
                        partyCritChanceWhileGoldAboveBonus: 1.0
                    )
                )),
                dealOpeningHand: false
            )
            battle.gold = gold
            return battle
        }
        var richBattle = makeBattle(gold: 50)
        var poorBattle = makeBattle(gold: 49)
        let richOutcome = richBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: richBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: richBattle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        let poorOutcome = poorBattle.resolveDamage(
            DamageRequest(
                amount: 3,
                target: poorBattle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: poorBattle.roster.hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(richOutcome.isCritical)
        #expect(!poorOutcome.isCritical)
    }

    @Test func thiefStealsEnemyBlockOnCriticalHit() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 20),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: .init(triggers: CombatTraitTriggers(
                attack: AttackTriggers(critStealEnemyBlock: true)
            )),
            dealOpeningHand: false
        )
        _ = battle.applyBlock(
            5,
            to: battle.roster.enemy.combatant,
            source: battle.roster.enemy.combatant,
            abilityName: "Test"
        )
        let companion = battle.roster.companion.combatant
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 2,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: companion.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    guaranteedCritical: true
                )
            )
        )
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant)) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: companion)) == 5)
    }

    @Test func thickHideReducesDamageTaken() throws {
        // Verify passiveMitigationFlat reduces damage by 1 using a zero-toughness
        // companion so toughness DR doesn't interfere with the expected value.
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(
                        passiveMitigationFlat: 1
                    )
                )
            )
        )
        context.roster.mutateRuntime(for: companion) { $0.currentHealth = 15 }
        _ = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: companion,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(context.roster.health(for: companion) == 11)
    }
}
