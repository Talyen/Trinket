import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension BattleTurnEngineTests {
    @Test(arguments: [Ability.sunder, .smite])
    func `enemy offensive effects affect the selected party member`(ability: Ability) throws {
        var context = try enemyTraitContext("skeleton")
        let enemy = context.enemy
        let target = context.hero
        DefensePoolEngine.set(20, on: target, in: &context)
        DefensePoolEngine.set(8, on: enemy, in: &context)

        let events = BattleTurnEngine.performAction(
            ability: ability, actor: enemy, abilityTarget: target, context: &context,
        )

        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 8)
        #expect(events.contains {
            ($0.effectKind == .shieldHalved || $0.effectKind == .purgeApplied) && $0.targetID == target.id
        })
    }

    @Test func `enemy poison dagger checks its original target after the first hit`() throws {
        var context = try enemyTraitContext("plague_doctor")
        let enemy = context.enemy
        context.roster.mutateRuntime(for: context.companion) { $0.currentHealth = 39 }
        let target = BattleTargetResolver.abilityTarget(for: enemy, in: context)

        let events = BattleTurnEngine.performAction(
            ability: .poisonDagger, actor: enemy, abilityTarget: target, context: &context,
        )

        let hits = events.filter { $0.kind == .abilityDamage }
        #expect(hits.map(\.keyword) == [.poison, .physical])
        #expect(hits.allSatisfy { $0.targetID == target.id })
        #expect(context.roster.companion.currentHealth == 39)
        #expect(!context.roster.hasAffliction(.poison, on: enemy))
    }

    @Test func `cleric holy damage restores its own health`() throws {
        var context = try enemyTraitContext("cleric")
        let enemy = context.enemy
        context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 5 }

        _ = context.resolveDamage(DamageRequest(
            amount: 2, target: context.hero, keyword: .holy, sourceActorID: enemy.id,
            options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(context.roster.enemy.currentHealth == 6)
        #expect(context.roster.hero.currentHealth == 38)
        #expect(context.roster.companion.currentHealth == 30)
    }

    @Test(arguments: [Keyword.holy, .stun])
    func `paladin gains block from its damage`(keyword: Keyword) throws {
        var context = try enemyTraitContext("paladin")
        _ = context.resolveDamage(DamageRequest(
            amount: 2, target: context.hero, keyword: keyword, sourceActorID: context.enemy.id,
            options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 1)
    }

    @Test func `zealot holy damage strengthens its next attack`() throws {
        var context = try enemyTraitContext("zealot")
        let target = context.hero
        let options = DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        _ = context.resolveDamage(DamageRequest(
            amount: 2, target: target, keyword: .holy, sourceActorID: context.enemy.id, options: options,
        ))

        let healthBefore = context.roster.health(for: target)
        _ = context.resolveDamage(DamageRequest(
            amount: 2, target: target, keyword: .physical, sourceActorID: context.enemy.id, options: options,
        ))

        #expect(healthBefore - context.roster.health(for: target) == 3)
        #expect(context.roster.enemy.pendingNextAttackHolyBonus == 0)
    }

    @Test func `yeti gains block for each party member frozen`() throws {
        var context = try enemyTraitContext("yeti")
        for target in [context.hero, context.companion] {
            _ = ControlMeterEngine.applyMeterCharge(
                100, keyword: .freeze, to: target, sourceActorID: context.enemy.id,
                applyFightPacing: false, in: &context,
            )
        }

        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 2)
        #expect(context.roster.hasPendingActionSkip(for: context.hero, keyword: .freeze))
        #expect(context.roster.hasPendingActionSkip(for: context.companion, keyword: .freeze))
    }

    @Test func `banshee deals bonus damage to A stunned party member`() throws {
        var context = try enemyTraitContext("banshee")
        let target = context.hero
        context.appendEffect(
            .controlMeter(.stun, 10, 10), to: target, sourceID: context.enemy.id, remainingTurns: 1,
        )

        let outcome = context.resolveDamage(DamageRequest(
            amount: 2, target: target, keyword: .physical, sourceActorID: context.enemy.id,
            options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(outcome.healthLost == 3)
    }

    private func enemyTraitContext(_ enemyID: String) throws -> BattleState {
        let definition = try #require(GameContent.enemy(matching: enemyID))
        let build = CombatBuildResolver.build(enemy: definition)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 50),
            enemy: build.combatant,
            heroHealth: 40,
            companionHealth: 30,
            enemyModifiers: build.modifiers,
        )
        context.appliesFightPacing = false
        return context
    }
}
