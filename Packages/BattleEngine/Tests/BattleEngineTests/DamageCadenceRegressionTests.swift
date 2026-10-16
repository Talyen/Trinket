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

    @Test(arguments: ["cauterize", "ashen_wake", "infected"], [false, true])
    func `conditional affixes strengthen ongoing damage without secondary packets`(id: String, conditioned: Bool) throws {
        let keyword: Keyword = id == "ashen_wake" ? .burn : .bleed
        let affix = try #require(GameContent.itemAffixDefinition(matching: id))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        if conditioned {
            let effect: Effect = id == "cauterize" ? .burn(1) : .poison(1)
            battle.insertEffect(effect, to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        let before = battle.health(of: battle.enemy)
        let outcome = battle.recordingResult { context in await DoTDamage.resolveDamage(
            basePotency: 4, keyword: keyword, target: context.enemy, sourceActorID: context.hero.id,
            operation: keyword == .burn ? .resolvedPeriodic : .periodic, in: &context,
        ) }
        #expect(before - battle.health(of: battle.enemy) == (conditioned ? 6 : 4))
        #expect(outcome.events.filter { $0.kind == .status }.map(\.keyword) == [keyword])
        #expect(!outcome.events.contains { $0.kind == .abilityDamage })
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
