// swiftlint:disable file_length
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

/// Catalog → `CombatBuildResolver` → live battle hooks for high-risk talent nodes.
struct TalentCatalogRoundTripTests { // swiftlint:disable:this type_body_length
    @Test func bastionStanceGrantsBlockEachRound() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_block_t1_1")
        #expect(build.modifiers.triggers.blockPerTurn == 2)
        #expect(!build.modifiers.triggers.blockRetainsThreeQuarters)
        #expect(build.modifiers.triggerAbilityName("blockPerTurn", fallback: "") == "Bastion Stance")
        var battle = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers
        )
        let events = CombatTriggerEngine.turnBlock(for: build.combatant, in: &battle)
        #expect(events.first?.abilityName == "Bastion Stance")
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: build.combatant)) == 2)
    }

    @Test func infernoBarrageUsesAuthoredBurnPotency() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "ranger", talents: "ranger_burn_t3_2")
        #expect(build.modifiers.triggers.ultimateAppliesBurnPotency == 8)
        let barrage = Ability(
            id: "inferno-test",
            name: "Barrage",
            tier: .ultimate,
            directDamage: 0
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [barrage],
            heroModifiers: build.modifiers,
            dealOpeningHand: true
        )
        _ = try BattleTestFixtures.playCardNamed("Barrage", owner: .hero, on: &battle)
        let burn = battle.roster.activeEffects(for: battle.roster.enemy.combatant)
            .first { $0.effect.keyword == .burn }
        #expect(burn?.effect.potency == 8)
    }

    @Test func unbreakableBlockRetainsThreeQuarters() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_block_t3_2")
        var battle = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers
        )
        _ = battle.applyBlock(8, to: build.combatant, source: build.combatant, abilityName: "Test")
        DefensePoolEngine.decayBlockAtEndOfRound(on: build.combatant, in: &battle)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: build.combatant)) == 6)
    }

    @Test func pureRadianceHolyDealsBonusDamageToBlock() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_holy_t1_2")
        var battle = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers
        )
        _ = battle.applyBlock(10, to: battle.roster.enemy.combatant, source: battle.roster.enemy.combatant, abilityName: "Test")
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant)) == 2)
    }

    @Test func intercedeAbsorbsCompanionDamageWithHeroBlock() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_block_t2_1")
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        var battle = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers
        )
        _ = battle.applyBlock(10, to: build.combatant, source: build.combatant, abilityName: "Test")
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
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: build.combatant)) == 6)
    }

    @Test func bountyHunterGrantsGoldOnCriticalDefeat() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "rogue", talents: "rogue_gold_t3_1")
        var battle = BattleStateTestFactory.makeBattle(
            hero: build.combatant,
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 5),
            heroModifiers: build.modifiers,
            dealOpeningHand: false
        )
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: build.combatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    guaranteedCritical: true
                )
            )
        )
        #expect(battle.lastEnemyDefeatWasCritical)
        _ = battle.appendDefeatMilestonesIfNeeded()
        #expect(battle.gold == 10)
    }

    @Test func reapersRushDealsBonusDamageToBleedingTarget() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "panther", talents: "panther_bleed_t3_2")
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: build.combatant,
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 40),
            companionModifiers: build.modifiers,
            dealOpeningHand: false
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 5,
                target: battle.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(outcome.healthLost == 10) // (5 base + 2 talent bonus) * 1.5x innate bleed trait
    }

    @Test func deepFreezeBlocksEnemyBlockAndHealing() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "wizard", talents: "wizard_freeze_t3_1")
        var battle = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            heroModifiers: build.modifiers
        )
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
            on: &battle
        )
        let blockEvents = battle.applyBlock(
            5,
            to: battle.roster.enemy.combatant,
            source: battle.roster.enemy.combatant,
            abilityName: "Test"
        )
        #expect(blockEvents.isEmpty)
        battle.roster.mutateRuntime(for: battle.roster.enemy.combatant) { $0.currentHealth = 10 }
        let heal = battle.resolveHeal(
            HealRequest(amount: 5, target: battle.roster.enemy.combatant, sourceActorID: battle.roster.enemy.id)
        )
        #expect(heal.healthRestored == 0)
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 10)
    }

    @Test func phoenixGiftHealsHeroFromFatalDamage() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "phoenix", talents: "phoenix_health_t3_1")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers
        )
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: hero,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(battle.roster.health(for: hero) == 3)
        #expect(battle.roster.runtime(for: build.combatant)?.hasTriggeredPhoenixGift == true)

        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: hero,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(battle.roster.health(for: hero) == 1)

        battle.roster.setActiveEffects([], for: hero)
        battle.roster.mutateRuntime(for: hero) {
            $0.hasConsumedDeathsDoor = true
            $0.deathsDoorExpiredAtTurn = -1
        }
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: hero,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(battle.roster.health(for: hero) == 0)
    }

    @Test func phoenixAfterglowHealsPartyOnDeathsDoor() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "phoenix", talents: "phoenix_health_t2_1")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers
        )
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        battle.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 10 }
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        let companionHeal = max(1, CombatRounding.scaled(battle.roster.maxHealth(for: build.combatant), multiplier: 0.15))
        let heroHeal = max(1, CombatRounding.scaled(battle.roster.maxHealth(for: hero), multiplier: 0.15))
        #expect(battle.roster.health(for: build.combatant) == 1 + companionHeal)
        #expect(battle.roster.health(for: hero) == 10 + heroHeal)
    }

    @Test func phoenixVigorBuffsDamageAfterSurvivingDeathsDoor() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "phoenix", talents: "phoenix_deathsdoor_t2_2")
        var battle = BattleTestFixtures.makeContext(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20),
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers
        )
        battle.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }
        _ = battle.resolveDamage(
            DamageRequest(
                amount: 40,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: "enemy",
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        #expect(battle.roster.runtime(for: build.combatant)?.talentDamagePercentBonus == 0.5)
    }

    @Test func piercingStarlightHolyIgnoresDodge() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "pixie", talents: "pixie_holy_t1_2")
        var battle = BattleTestFixtures.makeContext(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers,
            enemyModifiers: .init(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(dodgeChanceBonus: 1)
            ))
        )
        let outcome = battle.resolveDamage(
            DamageRequest(
                amount: 4,
                target: battle.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: true)
            )
        )
        #expect(outcome.healthLost == 4)
        #expect(!outcome.flags.contains(.dodged))
    }

    @Test func hoardArmorGrantsBlockFromCarriedGold() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "lizard_scout", talents: "lizard_scout_gold_t1_2")
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: build.combatant,
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            initialGold: 10,
            companionModifiers: build.modifiers,
            dealOpeningHand: false
        )
        _ = CombatTriggerEngine.atPlayerEndTurn(in: &battle)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: build.combatant)) == 2)
    }

    @Test func goldenGuardGrantsBlockAsPartyEarnsGold() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "golden_retriever", talents: "golden_retriever_gold_t2_2")
        var battle = BattleStateTestFactory.makeBattle(
            hero: BattleTestFixtures.passiveHero(),
            companion: build.combatant,
            enemy: BattleTestFixtures.silentEnemy(maxHealth: 100),
            companionModifiers: build.modifiers,
            dealOpeningHand: false
        )
        _ = battle.grantGoldEvent(4, to: battle.roster.hero.combatant, abilityName: "Test")
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: build.combatant)) == 2)
    }

    @Test func catalogProfileMergesSortedTalentIDs() {
        let profile = CombatantTalentCatalog.profile(for: ["knight_holy_t1_2", "knight_block_t3_2"])
        #expect(profile.triggers.holyBlockBreakMultiplier == 1.5)
        #expect(profile.triggers.blockRetainsThreeQuarters)
    }

    @Test func arcaneBreathCatalogEmpowersPerManaSpent() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "frost_whelp", talents: "frost_whelp_mana_t1_2")
        #expect(build.modifiers.triggers.spendManaDamageBonusPerMana == 3)
        var battle = BattleTestFixtures.makeContext(
            hero: BattleTestFixtures.passiveHero(),
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers
        )
        _ = CombatTriggerEngine.afterSpendMana(
            by: build.combatant,
            amountSpent: 1,
            in: &battle
        )
        #expect(battle.roster.runtime(for: build.combatant)?.pendingCardDamageBonus == 0)
        _ = CombatTriggerEngine.afterSpendMana(
            by: build.combatant,
            amountSpent: BattleTurnEngine.manaEmpowermentCost,
            in: &battle
        )
        #expect(
            battle.roster.runtime(for: build.combatant)?.pendingCardDamageBonus
                == BattleTurnEngine.manaEmpowermentCost * 3
        )
    }

    @Test func oathboundGrantsBlockOnHolyAndStunDamage() throws {
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_holy_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .holy,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(BattleTestFixtures.shieldPoints(for: build.combatant, in: context) == 2)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .stun,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(BattleTestFixtures.shieldPoints(for: build.combatant, in: context) == 4)
    }

    @Test func cutpurseGrantsGoldOnCriticalHit() throws {
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "rogue", talents: "rogue_gold_t1_1")
        var critContext = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )
        var nonCritContext = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )

        _ = critContext.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .physical,
                sourceActorID: build.combatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    guaranteedCritical: true
                )
            )
        )
        _ = nonCritContext.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .physical,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(critContext.gold == 2)
        try #expect(nonCritContext.gold == 0)
    }

    @Test func arcaneFocusAppliesRandomBurnOrFreezeOnSpendMana() throws {
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "wizard", talents: "wizard_mana_t1_1")

        var burnSeen = false
        var freezeSeen = false
        for seed in UInt64(0) ..< 32 {
            var context = BattleTestFixtures.makeContext(
                hero: build.combatant,
                companion: companion,
                enemy: enemy,
                heroModifiers: build.modifiers,
                seed: seed
            )
            let healthBefore = context.roster.health(for: enemy)
            _ = CombatTriggerEngine.afterSpendMana(by: build.combatant, amountSpent: 3, in: &context)
            let effects = context.roster.activeEffects(for: enemy)
            let hasBurn = effects.contains { active in
                if case .burn = active.effect {
                    return true
                }
                return false
            }
            if hasBurn {
                burnSeen = true
            }
            let hasFreezeMeter = effects.contains { $0.effect.keyword == .freeze }
            if hasFreezeMeter {
                freezeSeen = true
                try #expect(context.roster.health(for: enemy) == healthBefore)
            }
            if burnSeen, freezeSeen {
                break
            }
        }

        try #expect(burnSeen)
        try #expect(freezeSeen)
    }

    @Test func bloodfireHealsOnBurnDamage() throws {
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "warlock", talents: "warlock_burn_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 10 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .burn,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(context.roster.health(for: build.combatant) == 12)
    }

    @Test func packLeaderIncreasesCompanionBleedDamage() throws {
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let rangerBuild = try BattleTestFixtures.catalogBuild(combatantID: "ranger", talents: "ranger_bleed_t1_1")

        var context = BattleTestFixtures.makeContext(
            hero: rangerBuild.combatant,
            companion: wolf,
            enemy: enemy,
            heroModifiers: rangerBuild.modifiers
        )

        // Bleed damage receives pack bonus
        let bleedOutcome = context.resolveDamage(
            .directAbilityHit(amount: 1, target: enemy, keyword: .bleed, sourceActorID: wolf.id)
        )
        let bleedPackBonus = rangerBuild.modifiers.companionBleedDamageDealtBonus
        try #expect(bleedPackBonus == 3)
        try #expect(bleedOutcome.healthLost == 1 + bleedPackBonus)

        // Physical damage does not receive pack bleed bonus
        let physicalOutcome = context.resolveDamage(
            .directAbilityHit(amount: 1, target: enemy, keyword: .physical, sourceActorID: wolf.id)
        )
        let strengthPercent = wolf.primaryStats.statDamageBonusPercent(keyword: .physical)
        let strengthBonus = CombatRounding.scaled(1, multiplier: strengthPercent)
        try #expect(physicalOutcome.healthLost == 1 + strengthBonus)
    }

    @Test func faeFortuneGainsHealthWhenCleansing() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let pixieBuild = try BattleTestFixtures.catalogBuild(combatantID: "pixie", talents: "pixie_cleanse_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: pixieBuild.combatant,
            enemy: enemy,
            companionModifiers: pixieBuild.modifiers
        )
        context.roster.mutateRuntime(for: pixieBuild.combatant) { $0.currentHealth = 10 }
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 6, sourceActorID: enemy.id)],
            for: hero
        )

        _ = BattleTestFixtures.apply(
            .cleanseRandom,
            abilityName: "Cleanse",
            source: pixieBuild.combatant,
            target: hero,
            in: &context
        )

        try #expect(context.roster.health(for: pixieBuild.combatant) == 12)
        try #expect(context.roster.health(for: hero) == 10)
        try #expect(BattleTestFixtures.poisonPotency(on: hero, in: context) == 0)
    }

    @Test func purifyingWisdomDrawsCardWhenCleansing() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let owlBuild = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_cleanse_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: owlBuild.combatant,
            enemy: enemy,
            companionModifiers: owlBuild.modifiers
        )
        context.companionDeck.putOnBottom(.heal)
        while !context.hand.isEmpty {
            _ = context.hand.remove(id: context.hand.cards[0].id)
        }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 6, sourceActorID: enemy.id)],
            for: hero
        )

        let initialHandCount = context.hand.count
        _ = BattleTestFixtures.apply(
            .cleanseRandom,
            abilityName: "Cleanse",
            source: owlBuild.combatant,
            target: hero,
            in: &context
        )

        try #expect(context.hand.count == initialHandCount + 1)
        try #expect(BattleTestFixtures.poisonPotency(on: hero, in: context) == 0)
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

    @Test func coldBloodAppliesPoisonOnDodge() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "lizard_scout", talents: "lizard_scout_poison_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        _ = CombatTriggerEngine.afterDodge(by: build.combatant, attackerID: enemy.id, in: &context)

        try #expect(BattleTestFixtures.poisonPotency(on: enemy, in: context) == 2)
    }

    @Test func rebirthRevivesBeforeDeathsDoorThenDeathsDoorOnSecondLethal() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "phoenix", talents: "phoenix_deathsdoor_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 10)
        try #expect(context.roster.runtime(for: build.combatant)?.hasTriggeredDeathRevive == true)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant) == false)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant))
        try #expect(context.roster.isDeathsDoorActive(for: build.combatant))
    }

    @Test func deathrattleRevivesWithBlockBeforeDeathsDoor() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "risen_skeleton", talents: "risen_skeleton_deathsdoor_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(
            BattleTestFixtures.shieldPoints(for: build.combatant, in: context)
                == context.paced(10, sourceActorID: build.combatant.id)
        )
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant) == false)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant))
    }

    @Test func arcaneReservoirGrantsBlockOnSpendMana() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "mana_moth", talents: "mana_moth_mana_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        _ = CombatTriggerEngine.afterSpendMana(by: build.combatant, amountSpent: 3, in: &context)

        try #expect(BattleTestFixtures.shieldPoints(for: build.combatant, in: context) == 2)
    }

    @Test func carapaceGrantsBlockEachTurn() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = try BattleTestFixtures.catalogBuild(combatantID: "shield_scarab", talents: "shield_scarab_block_t1_1")
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        _ = EffectTurnEngine.advanceAll(context: &context)

        try #expect(BattleTestFixtures.shieldPoints(for: build.combatant, in: context) == 2)
    }

    @Test func protectiveBloomLogsAuthoredHealGrantBlockName() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "pixie", talents: "pixie_health_t2_2")
        #expect(build.modifiers.triggerAbilityName("onHealGrantBlock", fallback: "") == "Protective Bloom")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers
        )
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        let outcome = battle.resolveHeal(
            HealRequest(amount: 4, target: hero, sourceActorID: build.combatant.id)
        )
        #expect(outcome.events.contains {
            $0.abilityName == "Protective Bloom" && $0.effectKind == .shieldApplied && $0.amount == 2
        })
    }

    @Test func wardedRoostLogsAuthoredHealGrantBlockName() throws {
        let build = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_health_t1_2")
        #expect(build.modifiers.triggerAbilityName("onHealGrantBlock", fallback: "") == "Warded Roost")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = BattleTestFixtures.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            companionModifiers: build.modifiers
        )
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        let outcome = battle.resolveHeal(
            HealRequest(amount: 4, target: hero, sourceActorID: build.combatant.id)
        )
        #expect(outcome.events.contains {
            $0.abilityName == "Warded Roost" && $0.effectKind == .shieldApplied && $0.amount == 2
        })
    }
}
