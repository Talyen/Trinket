import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

// P0 gating and reaction-loop invariants from the talent mechanics review.
// swiftlint:disable:next type_body_length
struct TalentReviewFixTests {
    @Test func infernoBarrageUsesAuthoredBurnPotency() throws {
        let profile = CombatantTalentCatalog.profile(for: ["ranger_burn_t3_2"])
        #expect(profile.triggers.ultimateAppliesBurnPotency == 8)
        let barrage = Ability(
            id: "inferno-test",
            name: "Barrage",
            tier: .ultimate,
            directDamage: 0
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [barrage],
            heroModifiers: profile,
            dealOpeningHand: true
        )
        _ = try BattleTestFixtures.playCardNamed("Barrage", owner: .hero, on: &battle)
        let burn = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .first { $0.effect.keyword == .burn }
        #expect(burn?.effect.potency == 8)
    }

    @Test func purifyingAuraExtraDecaysPoisonWithoutASecondTick() {
        var withAura = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 40),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0)],
            heroModifiers: .init(triggers: CombatTraitTriggers(
                cleanse: CleanseTriggers(partyDebuffDurationHalved: true)
            )),
            dealOpeningHand: false
        )
        let healthBefore = withAura.roster.health(for: withAura.roster.hero.combatant)
        _ = EffectTurnEngine.advanceAll(context: &withAura)
        let remaining = withAura.roster.activeEffects(for: withAura.roster.hero.combatant)
            .compactMap(\.effect.potency)
            .first
        #expect(remaining == 2)
        let lost = healthBefore - withAura.roster.health(for: withAura.roster.hero.combatant)
        #expect(lost == Effect.poison(4).potencyAfterTurn())
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

    @Test func arcaneFocusCanChargeFreezeMeter() {
        var foundFreeze = false
        for seed in UInt64(0) ..< 80 {
            var battle = BattleStateTestFactory.makeBattle(
                hero: BattleTestFixtures.passiveHero(),
                companion: BattleTestFixtures.passiveCompanion(),
                enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
                heroModifiers: .init(triggers: CombatTraitTriggers(
                    mana: ManaTriggers(spendManaRandomDoTFlat: 1)
                )),
                rngSeed: seed,
                dealOpeningHand: false
            )
            let healthBefore = battle.roster.health(for: battle.roster.enemy.combatant)
            _ = CombatTriggerEngine.afterSpendMana(
                by: battle.roster.hero.combatant,
                amountSpent: 1,
                in: &battle
            )
            let hasMeter = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
                .contains { $0.effect.keyword == .freeze }
            if hasMeter {
                foundFreeze = true
                #expect(battle.roster.health(for: battle.roster.enemy.combatant) == healthBefore)
                break
            }
        }
        #expect(foundFreeze)
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

    @Test func phoenixGiftTriggersOncePerBattle() {
        let phoenixProfile = CombatModifierProfile(triggers: CombatTraitTriggers(
            revival: RevivalTriggers(onHeroFatalHealPercentMaxHealth: 0.5)
        ))
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(maxHealth: 40),
            companion: BattleTestFixtures.passiveCompanion(maxHealth: 40),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: phoenixProfile,
            dealOpeningHand: false
        )
        // First fatal blow heals Hero to 20 (50% max HP)
        _ = battle.resolveDamage(DamageRequest(
            amount: 50,
            target: battle.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.enemy.id
        ))
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 20)
        #expect(battle.roster.runtime(for: battle.roster.companion.combatant)?.hasTriggeredPhoenixGift == true)

        // Second fatal blow triggers baseline Hero Death's Door (clamped to 1 HP)
        _ = battle.resolveDamage(DamageRequest(
            amount: 50,
            target: battle.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.enemy.id
        ))
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 1)

        // Third fatal blow is fatal since Death's Door active effect expired and Phoenix Gift is consumed
        battle.roster.setActiveEffects([], for: battle.roster.hero.combatant)
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) {
            $0.hasConsumedDeathsDoor = true
            $0.deathsDoorExpiredAtTurn = -1
        }
        _ = battle.resolveDamage(DamageRequest(
            amount: 50,
            target: battle.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: battle.roster.enemy.id
        ))
        #expect(battle.roster.health(for: battle.roster.hero.combatant) == 0)
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
}
