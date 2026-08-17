import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

/// Catalog → `CombatBuildResolver` → live battle hooks for high-risk talent nodes.
struct TalentCatalogRoundTripTests {
    @Test func bastionStanceGrantsBlockEachRound() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["knight_block_t1_1"]
        )
        #expect(build.modifiers.triggers.blockPerTurn == 2)
        #expect(!build.modifiers.triggers.blockDoesNotDecay)
    }

    @Test func unbreakableBlockDoesNotDecay() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["knight_block_t3_2"]
        )
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["knight_holy_t1_2"]
        )
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.roster.enemy.combatant)) == 5)
    }

    @Test func intercedeAbsorbsCompanionDamageWithHeroBlock() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["knight_block_t2_1"]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let build = CombatBuildResolver.build(
            combatant: rogue,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["rogue_gold_t3_1"]
        )
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
        let panther = try #require(GameContent.companions.first { $0.id == "panther" })
        let build = CombatBuildResolver.build(
            combatant: panther,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["panther_bleed_t3_2"]
        )
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
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let build = CombatBuildResolver.build(
            combatant: wizard,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["wizard_freeze_t3_1"]
        )
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        let phoenix = try #require(GameContent.companions.first { $0.id == "phoenix" })
        let build = CombatBuildResolver.build(
            combatant: phoenix,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["phoenix_health_t3_1"]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
    }

    @Test func phoenixAfterglowHealsPartyOnDeathsDoor() throws {
        let phoenix = try #require(GameContent.companions.first { $0.id == "phoenix" })
        let build = CombatBuildResolver.build(
            combatant: phoenix,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["phoenix_health_t2_1"]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        let phoenix = try #require(GameContent.companions.first { $0.id == "phoenix" })
        let build = CombatBuildResolver.build(
            combatant: phoenix,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["phoenix_deathsdoor_t2_2"]
        )
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        let pixie = try #require(GameContent.companions.first { $0.id == "pixie" })
        let build = CombatBuildResolver.build(
            combatant: pixie,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["pixie_holy_t1_2"]
        )
        var battle = HeroCompanionTraitTestSupport.makeContext(
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
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        let build = CombatBuildResolver.build(
            combatant: lizard,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["lizard_scout_gold_t1_2"]
        )
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
        let retriever = try #require(GameContent.companions.first { $0.id == "golden_retriever" })
        let build = CombatBuildResolver.build(
            combatant: retriever,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["golden_retriever_gold_t2_2"]
        )
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
        #expect(profile.triggers.sunderingBlockMultiplier == 0.5)
        #expect(profile.triggers.blockDoesNotDecay)
    }
}
