import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension BattleTurnEngineTests {
    @Test(arguments: [false, true])
    func `ice wraith reduces damage from frozen party members`(frozen: Bool) throws {
        var context = try enemyTraitContext("ice_wraith")
        let actor = context.hero
        if frozen {
            context.appendEffect(.controlMeter(.freeze, 10, 10), to: actor, sourceID: context.enemy.id, remainingTurns: 1)
        }

        let outcome = context.resolveDamage(DamageRequest(
            amount: 5, target: context.enemy, keyword: .poison, sourceActorID: actor.id,
            options: .periodic,
        ))

        #expect(outcome.healthLost == (frozen ? 4 : 5))
    }

    @Test(arguments: [Keyword.burn, .physical])
    func `pyromancer bypasses flat and percentage defenses only with burn`(keyword: Keyword) throws {
        var defenses = CombatModifierProfile(damageTakenReduction: [.burn: 0.5, .physical: 0.5], damageTakenFlat: [.burn: 2, .physical: 2])
        defenses.triggers.passiveMitigationFlat = 2
        var context = try enemyTraitContext("pyromancer", heroModifiers: defenses)

        let outcome = context.resolveDamage(DamageRequest(
            amount: 10, target: context.hero, keyword: keyword, sourceActorID: context.enemy.id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(outcome.healthLost == (keyword == .burn ? 10 : 2))
    }

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

    @Test func `enemy poison dagger resolves two poison hits on its original target`() throws {
        var context = try enemyTraitContext("plague_doctor")
        let enemy = context.enemy
        context.roster.mutateRuntime(for: context.companion) { $0.currentHealth = 39 }
        let target = BattleTargetResolver.abilityTarget(for: enemy, in: context)

        let events = BattleTurnEngine.performAction(
            ability: .poisonDagger, actor: enemy, abilityTarget: target, context: &context,
        )

        let hits = events.filter { $0.kind == .abilityDamage }
        #expect(hits.map(\.keyword) == [.poison, .poison])
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
        #expect(context.roster.enemy.talents.pending.nextAttackHolyBonus == 0)
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

    @Test func `trait thorns skips zero-rounded reflection`() {
        var battle = BattleStateTestFactory.makeBattle(
            enemyModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(thornsPercent: 0.1),
            )),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let heroHealthBefore = battle.roster.hero.currentHealth
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: DamageOperation.attack(tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(outcome.healthLost == 1)
        #expect(!outcome.events.contains { $0.effectKind == .thornsTriggered })
        #expect(battle.roster.hero.currentHealth == heroHealthBefore)
    }

    @Test func `ambush applies only once through a composed build`() throws {
        var context = try enemyTraitContext("bandit")
        let target = context.hero
        let options = DamageOperation.attack(tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        for expectedDamage in [4, 2] {
            let healthBefore = context.health(of: target)
            _ = context.resolveDamage(DamageRequest(
                amount: 2, target: target, keyword: .physical, sourceActorID: context.enemy.id, options: options,
            ))
            #expect(healthBefore - context.health(of: target) == expectedDamage)
        }
    }

    @Test func `searing body retaliates while cold shocked remains a separate weakness`() throws {
        var context = try enemyTraitContext("fire_elemental")
        let hero = context.hero
        _ = context.resolveDamage(DamageRequest(
            amount: 1, target: context.enemy, keyword: .physical, sourceActorID: hero.id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(context.roster.hasAffliction(.burn, on: hero))
        #expect(context.enemyModifiers.damageTakenVulnerability[.freeze] == 0.30)
    }

    @Test func `cleric feedback names each independent trait`() throws {
        var context = try enemyTraitContext("cleric")
        let enemy = context.enemy
        context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 5 }
        let blockEvents = CombatTriggerEngine.turnBlock(for: enemy, in: &context)
        #expect(blockEvents.contains { $0.abilityName == "Watchful Guard" && $0.targetID == enemy.id })
        let outcome = context.resolveDamage(DamageRequest(
            amount: 2, target: context.hero, keyword: .holy, sourceActorID: enemy.id,
            options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(outcome.events.contains { $0.abilityName == "Restoring Light" && $0.targetID == enemy.id })
    }

    @Test(arguments: ["the_frostwarden", "the_iron_bear", "the_blight_treant", "the_forge_golem",
                      "the_blood_countess", "the_seraph", "the_stone_titan"])
    func `split boss auras keep their every other round cadence`(enemyID: String) throws {
        var context = try enemyTraitContext(enemyID)
        let enemy = context.enemy
        for turn in 1 ... 4 {
            context.turnCount = turn
            let heroHealth = context.health(of: context.hero)
            let companionHealth = context.health(of: context.companion)
            _ = EnemyTraitEngine.turnFreeze(for: enemy, context: &context)
            _ = EnemyTraitEngine.turnRandomDamageAllEnemies(for: enemy, context: &context)
            let expectedDamage = turn.isMultiple(of: 2) ? 1 : 0
            #expect(heroHealth - context.health(of: context.hero) == expectedDamage)
            #expect(companionHealth - context.health(of: context.companion) == expectedDamage)
        }
    }

    private func enemyTraitContext(_ enemyID: String, heroModifiers: CombatModifierProfile = .zero) throws -> BattleState {
        let definition = try #require(GameContent.enemy(matching: enemyID))
        let build = CombatBuildResolver.build(enemy: definition)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 50),
            enemy: build.combatant,
            heroHealth: 40,
            companionHealth: 30,
            heroModifiers: heroModifiers,
            enemyModifiers: build.modifiers,
        )
        context.appliesFightPacing = false
        return context
    }
}
