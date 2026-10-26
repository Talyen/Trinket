import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct EnemyIdentityTraitTests {
    @Test func `blood offering pays once for multiple hits and applies bleed`() throws {
        var context = try makeBattle("blood_cultist")
        let enemy = context.enemy
        let target = context.hero
        let health = context.roster.enemy.currentHealth
        DefensePoolEngine.set(10, on: enemy, in: &context)
        let attack = Ability(
            id: "offering_attack", name: "Offering Attack", tier: .basic,
            operations: [.damage(DamageComponent(1, keyword: .physical)),
                         .damage(DamageComponent(1, keyword: .physical))],
        )

        let events = context.performTestAction(attack, from: .enemy, to: .hero)

        #expect(context.roster.enemy.currentHealth == health - 1)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 10)
        #expect(context.roster.hasAffliction(.bleed, on: target))
        #expect(events.count(where: { $0.abilityName == "Blood Offering" && $0.targetID == enemy.id }) == 1)
    }

    @Test func `blood offering cannot spend its last health and support is free`() throws {
        var context = try makeBattle("blood_cultist")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 1 }
        let health = context.roster.hero.currentHealth

        #expect(!BattleAbilityRules.canPayHealthCost(.rendingSlash, actor: context.enemy, in: context))
        context.performTestAction(.rendingSlash, from: .enemy, to: .hero)
        #expect(context.roster.hero.currentHealth == health)
        #expect(context.roster.enemy.currentHealth == 1)

        let support = Ability(id: "offering_guard", name: "Offering Guard", tier: .skill, effects: [.shield(.block, 2)])
        context.performTestAction(support, from: .enemy, to: .hero)
        #expect(context.roster.enemy.currentHealth == 1)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 2)
    }

    @Test(arguments: [Keyword.poison, .physical])
    func `plague mask heals only for opponent poison damage`(keyword: Keyword) throws {
        var context = try makeBattle("plague_doctor")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }

        context.resolveTestDamage(2, from: .enemy, to: .hero, keyword: keyword, options: .periodic)

        #expect(context.roster.enemy.currentHealth == (keyword == .poison ? 6 : 5))
    }

    @Test func `plague mask ignores blocked poison and poison to itself`() throws {
        var context = try makeBattle("plague_doctor")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }
        DefensePoolEngine.set(10, on: context.hero, in: &context)

        context.resolveTestDamage(2, from: .enemy, to: .hero, keyword: .poison, options: .periodic)
        #expect(context.roster.enemy.currentHealth == 5)
        let outcome = context.resolveTestDamage(3, keyword: .poison, options: .periodic)
        #expect(context.roster.enemy.currentHealth == 5 - outcome.healthLost)
    }

    @Test func `reform heals at turn start even when the action is skipped`() throws {
        var context = try makeBattle("mud_elemental")
        let enemy = context.enemy
        context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 5 }
        context.insertEffect(.controlMeter(.stun, 10, 10), to: enemy, remainingTurns: 1)
        let health = context.roster.hero.currentHealth

        let events = context.recordingEvents { context in
            await BattleCardCombatEngine.resolveEnemyTurn(context: &context)
        }

        #expect(context.roster.enemy.currentHealth == 6)
        #expect(context.roster.hero.currentHealth == health)
        #expect(events.contains { $0.abilityName == "Reform" && $0.effectKind == .instantHeal && $0.amount == 1 })
    }

    @Test(arguments: [Ability.kindling, .fireball])
    func `firestarter applies burn only to basic actions`(ability: Ability) throws {
        var context = try makeBattle("fire_imp")
        let enemy = context.enemy
        let definition = try #require(GameContent.enemy(matching: "fire_imp"))
        let controlBuild = CombatBuildResolver.build(enemy: definition)
        var profile = controlBuild.modifiers
        profile.triggers.basicAttackApplyBurn = 0
        var control = try makeBattle("fire_imp", enemyModifiers: profile)

        context.performTestAction(ability, from: .enemy, to: .hero)
        control.performTestAction(ability, from: .enemy, to: .hero)

        let burn = context.roster.activeEffects(for: context.hero).filter { $0.effect.keyword == .burn }
            .reduce(0) { $0 + ($1.effect.potency ?? 0) }
        let originalBurn = control.roster.activeEffects(for: control.hero).filter { $0.effect.keyword == .burn }
            .reduce(0) { $0 + ($1.effect.potency ?? 0) }
        #expect(burn == originalBurn + (ability.tier == .basic ? 1 : 0))
        #expect(context.roster.activeEffects(for: enemy).allSatisfy { $0.effect.keyword != .burn })
    }

    @Test func `pilfer steals before damage and keeps the selected opponent`() throws {
        var context = try makeBattle("goblin")
        let target = context.hero
        DefensePoolEngine.set(1, on: target, in: &context)
        DefensePoolEngine.set(4, on: context.companion, in: &context)
        let attack = Ability(id: "pilfer_attack", name: "Pilfer Attack", tier: .basic, directDamage: 1, damageKeyword: .physical)

        let events = context.performTestAction(attack, from: .enemy, to: .hero)

        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 1)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.companion.activeEffects) == 4)
        let theft = try #require(events.firstIndex { $0.effectKind == .blockStripped && $0.targetID == target.id })
        let hit = try #require(events.firstIndex { $0.kind == .abilityDamage && $0.targetID == target.id })
        #expect(theft < hit)
    }

    @Test(arguments: [false, true])
    func `hollow frame prevents guaranteed and chance leech`(chance: Bool) throws {
        var context = try makeBattle("skeleton", heroModifiers: .withTriggers {
            $0.leechChancePercent = chance ? 1 : 0
            $0.onLeechApplyPoison = 2
        })
        let health = context.roster.hero.currentHealth
        let outcome = context.resolveTestDamage(
            4, options: .attack(accuracy: .unavoidable, abilityHasLeech: !chance),
        )

        #expect(outcome.healthLost > 0)
        #expect(!outcome.flags.contains(.leeched))
        #expect(context.roster.hero.currentHealth == health)
        #expect(!context.roster.hasAffliction(.poison, on: context.enemy))
    }

    @Test func `hollow frame prevents companion leech transfers`() throws {
        var context = try makeBattle("skeleton", companionModifiers: .withTriggers {
            $0.companionDamageLeechesToHeroPercent = 1
        })
        let health = context.roster.hero.currentHealth

        context.resolveTestDamage(4, from: .companion, options: .attack(accuracy: .unavoidable))

        #expect(context.roster.hero.currentHealth == health)
    }

    private func makeBattle(
        _ enemyID: String,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile? = nil,
    ) throws -> BattleState {
        let enemy = try #require(GameContent.enemy(matching: enemyID))
        let build = CombatBuildResolver.build(enemy: enemy)
        return BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 50),
            enemy: build.combatant, heroHealth: 40, companionHealth: 30,
            heroModifiers: heroModifiers, companionModifiers: companionModifiers, enemyModifiers: enemyModifiers ?? build.modifiers,
            appliesFightPacing: false,
        )
    }
}
