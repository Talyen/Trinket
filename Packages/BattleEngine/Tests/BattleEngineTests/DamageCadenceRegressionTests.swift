import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DamageCadenceRegressionTests {
    @Test(arguments: ["dire_wolf", "stone_golem", "banshee", "hellhound"])
    func `enemy attack traits do not amplify ongoing damage`(enemyID: String) throws {
        let enemy = try #require(GameContent.enemy(matching: enemyID))
        let build = CombatBuildResolver.build(enemy: enemy)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: build.combatant, enemyModifiers: build.modifiers,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.bleed(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        battle.appendEffect(.burn(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.controlMeter(.stun, 20, 20), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        DefensePoolEngine.set(1, on: battle.enemy, in: &battle)
        let tick = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.hero, keyword: .bleed, sourceActorID: battle.enemy.id, options: .periodic,
        ))
        #expect(tick.healthLost == 4)
        let attack = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.hero, keyword: .bleed, sourceActorID: battle.enemy.id,
            options: .attack(accuracy: .unavoidable),
        ))
        #expect(attack.healthLost == 5)
    }

    @Test func `Stormbreak doubles Bleed ticks against Stunned enemies`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.stunnedDamageMultiplier = 2
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.appliesFightPacing = false
        battle.appendEffect(.controlMeter(.stun, 10, 10), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
        let tick = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: .bleed, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle,
        ) }
        #expect(tick.healthLost == 8)
    }

    @Test(arguments: [Keyword.bleed, .burn])
    func `damage conversions react to ticks without requiring a new stack`(keyword: Keyword) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedApplyPoison = 2
        profile.triggers.onBleedDealPoisonChancePercent = 1
        profile.triggers.onBurnApplyPoison = 2
        profile.triggers.onBurnDealPoisonChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.appliesFightPacing = false
        let before = battle.health(of: battle.enemy)
        _ = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: keyword, target: battle.enemy, sourceActorID: battle.hero.id,
            operation: keyword == .burn ? .resolvedPeriodic : .periodic, in: &battle,
        ) }
        #expect(battle.health(of: battle.enemy) == before - 6)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 2)
    }

    @Test func `Infected shares one successful conversion per wearer per turn across Bleed packets`() throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "infected"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.onBleedDealPoisonChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, companionModifiers: profile)
        battle.appliesFightPacing = false
        func tick(from actor: Combatant, in battle: inout BattleState) {
            _ = battle.resolveDamage(.doTTick(amount: 2, target: battle.enemy, keyword: .bleed, sourceActorID: actor.id))
        }
        tick(from: battle.hero, in: &battle)
        tick(from: battle.hero, in: &battle)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 1)
        tick(from: battle.companion, in: &battle)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 2)
        battle.turnCount += 1
        tick(from: battle.hero, in: &battle)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 3)
    }

    @Test func `Cauterize reacts to ongoing Bleed damage`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedDealBurnDamage = 2
        profile.triggers.onBleedDealBurnChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.appliesFightPacing = false
        let before = battle.health(of: battle.enemy)
        _ = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4,
            keyword: .bleed,
            target: battle.enemy,
            sourceActorID: battle.hero.id,
            in: &battle,
        ) }
        #expect(battle.health(of: battle.enemy) == before - 6)
    }

    @Test(arguments: [Keyword.bleed, .burn])
    func `silent stacks and fully blocked damage do not trigger conversions`(keyword: Keyword) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedApplyPoison = 2
        profile.triggers.onBleedDealPoisonChancePercent = 1
        profile.triggers.onBurnApplyPoison = 2
        profile.triggers.onBurnDealPoisonChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile)
        battle.appliesFightPacing = false
        _ = CombatExecutor.run { await DoTApplicator.applyDoT(
            keyword: keyword, potency: 4, to: battle.enemy, sourceActorID: battle.hero.id,
            application: .attached, in: &battle,
        ) }
        DefensePoolEngine.set(100, on: battle.enemy, in: &battle)
        let tick = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: keyword, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle,
        ) }
        #expect(tick.healthLost == 0)
        #expect(battle.health(of: battle.enemy) == 50)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 0)
    }
}
