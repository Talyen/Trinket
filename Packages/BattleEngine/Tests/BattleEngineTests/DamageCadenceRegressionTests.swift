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
            enemy: build.combatant, enemyModifiers: build.modifiers, appliesFightPacing: false,
        )
        battle.insertEffect(.bleed(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        battle.insertEffect(.burn(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.insertEffect(.controlMeter(.stun, 20, 20), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        DefensePoolEngine.set(1, on: battle.enemy, in: &battle)
        let tick = battle.resolveTestDamage(4, from: .enemy, to: .hero, keyword: .bleed, options: .periodic)
        #expect(tick.healthLost == 4)
        let attack = battle.resolveTestDamage(4, from: .enemy, to: .hero, keyword: .bleed, options: .attack(accuracy: .unavoidable))
        #expect(attack.healthLost == 5)
    }

    @Test func `Stormbreak doubles Bleed ticks against Stunned enemies`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.stunnedDamageMultiplier = 2
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        battle.insertEffect(.controlMeter(.stun, 10, 10), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
        let tick = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: .bleed, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle,
        ) }
        #expect(tick.healthLost == 8)
    }

    @Test func `Infected reacts to ticks without requiring a new stack`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedApplyPoison = 2
        profile.triggers.onBleedDealPoisonChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        let before = battle.health(of: battle.enemy)
        _ = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: .bleed, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle,
        ) }
        #expect(battle.health(of: battle.enemy) == before - 6)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 2)
    }

    @Test func `Infected shares one successful conversion per wearer per turn across Bleed packets`() throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "infected"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.onBleedDealPoisonChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, companionModifiers: profile, appliesFightPacing: false)
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

    @Test(arguments: [Keyword.bleed, .burn], [false, true])
    func `conditional affixes strengthen ongoing damage without secondary packets`(keyword: Keyword, conditioned: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: keyword == .bleed ? "cauterize" : "ashen_wake"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        if conditioned {
            let effect: Effect = keyword == .bleed ? .burn(1) : .poison(1)
            battle.insertEffect(effect, to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        let before = battle.health(of: battle.enemy)
        let outcome = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: keyword, target: battle.enemy, sourceActorID: battle.hero.id,
            operation: keyword == .burn ? .resolvedPeriodic : .periodic, in: &battle,
        ) }
        #expect(before - battle.health(of: battle.enemy) == (conditioned ? 6 : 4))
        #expect(outcome.events.filter { $0.kind == .status }.map(\.keyword) == [keyword])
        #expect(!outcome.events.contains { $0.kind == .abilityDamage })
    }

    @Test func `silent Bleed stacks and fully blocked damage do not trigger Infected`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedApplyPoison = 2
        profile.triggers.onBleedDealPoisonChancePercent = 1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        _ = CombatExecutor.run { await DoTApplicator.applyDoT(
            keyword: .bleed, potency: 4, to: battle.enemy, sourceActorID: battle.hero.id,
            application: .attached, in: &battle,
        ) }
        DefensePoolEngine.set(100, on: battle.enemy, in: &battle)
        let tick = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 4, keyword: .bleed, target: battle.enemy, sourceActorID: battle.hero.id, in: &battle,
        ) }
        #expect(tick.healthLost == 0)
        #expect(battle.health(of: battle.enemy) == 50)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 0)
    }

    @Test func `Dazing Swipe adds one control charge per Physical ability without another damage packet`() {
        var profile = CombatantTalentCatalog.profile(for: ["bear_stun_t1_2"])
        profile.triggers.dazingSwipeChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        let ability = Ability(
            id: "double-swipe", name: "Double Swipe", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .physical), DamageComponent(1, keyword: .physical)],
            criticalChanceBonus: -1,
        )
        let events = battle.performTestAction(ability)
        #expect(battle.health(of: battle.enemy) == 98)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.physical, .physical])
        let meter = battle.activeEffects(of: battle.enemy).first { $0.effect.kind == .controlMeter }
        #expect(meter?.effect == .controlMeter(.stun, 4, 20))
    }
}
