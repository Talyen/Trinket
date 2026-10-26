import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct EnemyIdentityTraitTests {
    @Test func `self sacrifice and bloodletting follow every direct attack hit`() throws {
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

        #expect(context.roster.enemy.currentHealth == health - 2)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 10)
        #expect(context.roster.activeEffects(for: target).count(where: { $0.effect.isBleed }) == 2)
        #expect(events.count(where: { $0.abilityName == "Self-Sacrifice" && $0.targetID == enemy.id }) == 2)
    }

    @Test func `self sacrifice permits a final attack and support has no recoil`() throws {
        var context = try makeBattle("blood_cultist")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 1 }
        let health = context.roster.hero.currentHealth
        let support = Ability(id: "offering_guard", name: "Offering Guard", tier: .skill, effects: [.shield(.block, 2)])
        context.performTestAction(support, from: .enemy, to: .hero)
        #expect(context.roster.enemy.currentHealth == 1)
        #expect(BattleAbilityRules.canPayHealthCost(.rendingSlash, actor: context.enemy, in: context))

        let events = context.performTestAction(.rendingSlash, from: .enemy, to: .hero)
        #expect(context.roster.hero.currentHealth < health)
        #expect(context.roster.enemy.currentHealth == 0)
        let recoil = try #require(events.firstIndex { $0.abilityName == "Self-Sacrifice" })
        let attack = try #require(events.firstIndex { $0.kind == .abilityDamage && $0.targetID == context.hero.id })
        #expect(attack < recoil)
    }

    @Test func `siphon restores per hit and ignores ongoing damage and support`() throws {
        var context = try makeBattle("necromancer")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }
        let attack = Ability(
            id: "double_hit",
            name: "Double Hit",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .physical), DamageComponent(1, keyword: .physical)],
        )
        context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(context.roster.enemy.currentHealth == 7)
        context.resolveTestDamage(2, from: .enemy, to: .hero, keyword: .bleed, options: .periodic)
        context.performTestAction(.block, from: .enemy, to: .hero)
        #expect(context.roster.enemy.currentHealth == 7)
    }

    @Test func `pyromancy strengthens every Burn hit while Block still absorbs damage`() throws {
        var context = try makeBattle("pyromancer")
        DefensePoolEngine.set(10, on: context.hero, in: &context)
        let health = context.roster.hero.currentHealth
        let attack = Ability(
            id: "double_burn",
            name: "Double Burn",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .burn), DamageComponent(2, keyword: .burn)],
        )
        let events = context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(context.roster.hero.currentHealth == health)
        #expect(events.filter { $0.effectKind == .shieldAbsorbed }.reduce(0) { $0 + $1.amount } == 6)
    }

    @Test(arguments: [24, 25])
    func `condemn adds Holy damage to every hit strictly below half Health`(health: Int) throws {
        var context = try makeBattle("inquisitor")
        context.roster.mutateRuntime(for: context.hero) { $0.currentHealth = health }
        let attack = Ability(
            id: "double_hit",
            name: "Double Hit",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .physical), DamageComponent(1, keyword: .physical)],
        )
        // At half Health the first hit crosses the threshold; only the later hit qualifies.
        context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(context.roster.hero.currentHealth == health - (health == 24 ? 4 : 3))
        var atHalf = try makeBattle("inquisitor")
        atHalf.roster.mutateRuntime(for: atHalf.hero) { $0.currentHealth = 25 }
        atHalf.performTestAction(.slash, from: .enemy, to: .hero)
        #expect(atHalf.roster.hero.currentHealth == 22)
    }

    @Test func `cowardly reduces the whole attack once below half Health`() throws {
        let enemy = try #require(GameContent.enemy(matching: "bandit"))
        var profile = CombatBuildResolver.build(enemy: enemy).modifiers
        profile.triggers.firstHitDoubleDamage = false
        var context = try makeBattle("bandit", enemyModifiers: profile)
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }
        let health = context.roster.hero.currentHealth
        let attack = Ability(
            id: "double_hit",
            name: "Double Hit",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical), DamageComponent(2, keyword: .physical)],
        )
        context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(context.roster.hero.currentHealth == health - (health == 24 ? 4 : 3))
    }

    @Test(arguments: [Keyword.poison, .physical])
    func `plague mask heals only for opponent poison damage`(keyword: Keyword) throws {
        var context = try makeBattle("plague_doctor")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }

        context.resolveTestDamage(2, from: .enemy, to: .hero, keyword: keyword, options: .periodic)

        #expect(context.roster.enemy.currentHealth == (keyword == .poison ? 6 : 5))
    }

    @Test func `plague mask heals through Block but ignores poison to itself`() throws {
        var context = try makeBattle("plague_doctor")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }
        DefensePoolEngine.set(10, on: context.hero, in: &context)

        context.resolveTestDamage(2, from: .enemy, to: .hero, keyword: .poison, options: .periodic)
        #expect(context.roster.enemy.currentHealth == 6)
        let outcome = context.resolveTestDamage(3, keyword: .poison, options: .periodic)
        #expect(context.roster.enemy.currentHealth == 6 - outcome.healthLost)
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
    func `firestarter applies burn to attack hits of every tier`(ability: Ability) throws {
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
        #expect(burn == originalBurn + 1)
        #expect(context.roster.activeEffects(for: enemy).allSatisfy { $0.effect.keyword != .burn })
    }

    @Test func `blocked multi-hit Holy attacks restore cleric Health for each hit`() throws {
        var context = try makeBattle("cleric")
        context.roster.mutateRuntime(for: context.enemy) { $0.currentHealth = 5 }
        DefensePoolEngine.set(20, on: context.hero, in: &context)
        let health = context.roster.hero.currentHealth
        let attack = Ability(
            id: "double_holy", name: "Double Holy", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .holy), DamageComponent(2, keyword: .holy)],
        )
        context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(context.roster.enemy.currentHealth == 7)
        #expect(context.roster.hero.currentHealth == health)
    }

    @Test func `paladin receives each matching hit reward through Block`() throws {
        var context = try makeBattle("paladin")
        DefensePoolEngine.set(20, on: context.hero, in: &context)
        let attack = Ability(
            id: "mixed_holy_stun", name: "Mixed Holy Stun", tier: .skill,
            damageComponents: [DamageComponent(2, keyword: .holy), DamageComponent(2, keyword: .stun)],
        )
        context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 2)
    }

    @Test func `pilfer steals on each attempted hit without stealing extra for trait damage`() throws {
        var context = try makeBattle("goblin")
        DefensePoolEngine.set(20, on: context.hero, in: &context)
        let attack = Ability(
            id: "double_pilfer", name: "Double Pilfer", tier: .skill,
            damageComponents: [DamageComponent(1, keyword: .physical), DamageComponent(1, keyword: .physical)],
        )
        context.performTestAction(attack, from: .enemy, to: .hero)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.enemy.activeEffects) == 2)
        #expect(DefensePoolEngine.blockPoints(in: context.roster.hero.activeEffects) == 16)
    }

    @Test func `concussion survives utility and weakens all hits of the next attack`() throws {
        var context = try makeBattle("brawler", enemyModifiers: .withTriggers {
            $0.stunnedEnemyNextTurnDamageMultiplier = 0.75
        })
        let hero = context.hero
        context.insertEffect(.controlMeter(.stun, 10, 10), to: hero, remainingTurns: 1)
        context.recordingEvents { context in
            await BattleTurnEngine.consumeActionSkip(for: hero, context: &context)
        }
        #expect(context.roster.hero.talents.pending.concussionMultiplier == 0.75)
        context.performTestAction(.block, from: .hero, to: .enemy)
        #expect(context.roster.hero.talents.pending.concussionMultiplier == 0.75)
        let health = context.roster.enemy.currentHealth
        let attack = Ability(
            id: "concussed_double", name: "Concussed Double", tier: .skill,
            damageComponents: [DamageComponent(4, keyword: .physical), DamageComponent(4, keyword: .physical)],
        )
        context.performTestAction(attack, from: .hero, to: .enemy)
        #expect(context.roster.hero.talents.pending.concussionMultiplier == 1)
        #expect(context.roster.enemy.currentHealth == health - 6)
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

    @Test(arguments: [false, true])
    func `hollow frame prevents guaranteed leech followup rewards`(immune: Bool) throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton"))
        var enemyProfile = CombatBuildResolver.build(enemy: enemy).modifiers
        enemyProfile.triggers.cannotBeLeeched = immune
        let talents = CombatantTalentCatalog.profile(for: ["risen_skeleton_leech_t1_1", "risen_skeleton_leech_t1_2"])
        var context = try makeBattle("skeleton", companionModifiers: talents, enemyModifiers: enemyProfile)

        let outcome = context.resolveTestDamage(
            2, from: .companion,
            options: .attack(accuracy: .unavoidable, guaranteedCritical: true, abilityHasLeech: true),
        )

        #expect(outcome.healthLost > 0)
        #expect(outcome.flags.contains(.leeched) == !immune)
        #expect(context.roster.enemy.talents.pending.nextOutgoingAttackMultiplier == (immune ? 1 : 0.75))
        #expect(context.roster.companion.talents.pending.nextLeechCriticalPoisonAttackBonus?.value == (immune ? nil : 3))
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
