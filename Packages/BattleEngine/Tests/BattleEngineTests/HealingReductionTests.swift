import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingReductionTests {
    @Test(arguments: [0, 1])
    func `blood link applies hero healing reduction before transferring excess`(missingHealth: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 40, companionMaxHealth: 40,
            heroMaxMana: 3,
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t2_1", "warlock_leech_t2_2"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentMana = 0
        battle.roster.hero.currentHealth -= missingHealth
        battle.roster.companion.currentHealth = 1
        battle.insertEffect(.healingReductionPercent(0.5, 3), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 3)
        let outcome = CombatExecutor.run { await HealingEngine.leechFromDamage(
            16, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        ) }
        #expect(outcome.flags.contains(.leeched))
        #expect(battle.roster.hero.currentMana == 0)
        #expect(battle.roster.hero.currentHealth == 40)
        #expect(battle.roster.companion.currentHealth == 1 + 4 - missingHealth)
    }

    @Test func `healing logging cannot change leech rules or randomness`() {
        var silent = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            heroHealth: 10,
            heroModifiers: .withTriggers { $0.criticalChanceBonus = 0.5 },
        )
        var visible = silent
        let silentResult = silent.resolveHeal(HealRequest(
            amount: 5, target: silent.hero, sourceActorID: silent.hero.id, origin: .leech,
        ))
        let visibleResult = visible.resolveHeal(HealRequest(
            amount: 5, target: visible.hero, sourceActorID: visible.hero.id, origin: .leech,
            logAs: .instantHeal(source: .init(visible.hero), abilityName: "Leech", keyword: .health),
        ))
        #expect(silentResult.healthRestored == visibleResult.healthRestored)
        #expect(silentResult.isCritical == visibleResult.isCritical)
        for owner in [BattleParticipant.hero, .companion, .enemy] {
            #expect(silent.roster[owner] == visible.roster[owner])
        }
        #expect(silent.rng.next() == visible.rng.next())
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `enemy serrated edge reduces only the afflicted ally healing`(recipient: BattleParticipant) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(abilities: [.serratedEdge]), appliesFightPacing: false,
        )
        let target = battle.roster[recipient].combatant
        BattleTurnEngine.performAction(
            ability: .serratedEdge, actor: battle.enemy, abilityTarget: target, context: &battle,
        )

        for ally in [battle.hero, battle.companion] {
            battle.roster.mutateRuntime(for: ally) { $0.currentHealth = 10 }
            let outcome = battle.resolveHeal(HealRequest(
                amount: 8, target: ally, sourceActorID: ally.id, logAs: .silent,
            ))
            #expect(outcome.healthRestored == (ally.id == target.id ? 6 : 8))
        }
    }

    @Test(arguments: [BattleParticipant.enemy, .hero])
    func `serrated edge reduces enemy healing and leaves ally healing alone`(recipient: BattleParticipant) {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.serratedEdge]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            dealOpeningHand: false,
        )
        let target = battle.roster[recipient].combatant
        battle.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }
        _ = battle.performTestAction(.serratedEdge)
        let outcome = battle.resolveHeal(HealRequest(
            amount: 8, target: target, sourceActorID: target.id, logAs: .silent, skipFightPacing: true,
        ))
        #expect(outcome.healthRestored == (recipient == .enemy ? 6 : 8))
        if recipient == .enemy {
            #expect(battle.health(of: target) == 14)
        }
    }

    @Test func `healing triggered block uses the healers outgoing bonus`() {
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: CombatModifierProfile(blockGainedBonus: 7),
            companionModifiers: CombatModifierProfile(
                blockGainedBonus: 3,
                triggers: CombatTraitTriggers.configured { $0.onHealGrantBlock = 2 },
            ), appliesFightPacing: false,
        )
        let hero = battle.roster.hero.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }

        let outcome = battle.resolveHeal(HealRequest(amount: 1, target: hero, sourceActorID: battle.roster.companion.id))

        let block = outcome.events.first { $0.effectKind == .shieldApplied }
        #expect(block?.amount == 5)
        #expect(block?.actorName == battle.roster.companion.name)
    }

    @Test func `healing triggered cleanse rewards the healer`() {
        var battle = BattleStateTestFactory.makeBattle(
            companionModifiers: CombatModifierProfile.withTriggers {
                $0.cleanseSelfHeal = 3
                $0.onHealCleanseTargetChance = 1
            }, appliesFightPacing: false,
        )
        let hero = battle.roster.hero.combatant
        let companion = battle.roster.companion.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        battle.roster.mutateRuntime(for: companion) { $0.currentHealth = 1 }
        battle.insertEffect(.poison(3), to: hero, sourceID: battle.roster.enemy.id, remainingTurns: 0)

        let outcome = battle.resolveHeal(HealRequest(amount: 1, target: hero, sourceActorID: companion.id))

        #expect(battle.roster.hero.currentHealth == 2)
        #expect(battle.roster.companion.currentHealth == 4)
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect.isRemovableDebuff })
        #expect(outcome.events.first { $0.effectKind == .cleanseApplied }?.actorName == companion.name)
    }
}

extension HealingReductionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `shared leech does not apply healing bonuses twice`(owner: BattleParticipant) {
        var profile = CombatModifierProfile(healthRestoredBonus: 4)
        if owner == .hero {
            profile.triggers.companionLeechSharePercent = 0.5
        } else {
            profile.triggers.leechSharesToHeroPercent = 0.5
        }
        profile.triggers.criticalChanceBonus = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 100, companionMaxHealth: 100,
            heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 10
        battle.roster.companion.currentHealth = 10
        let outcome = CombatExecutor.run { await HealingEngine.leechFromDamage(
            16, sourceActorID: battle.roster[owner].id, target: battle.enemy, abilityHasLeech: true, in: &battle,
        ) }
        #expect(outcome.healthRestored == 24)
        let recipient: BattleParticipant = owner == .hero ? .companion : .hero
        #expect(battle.roster[recipient].currentHealth == 22)
    }
}

extension HealingReductionTests {
    @Test(arguments: [0, 10])
    func `bloodprice reduces enemy healing while its companion survives`(heroHealth: Int) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: heroHealth,
            companionModifiers: CombatantTalentCatalog.profile(for: ["panther_bleed_t3_2"]), appliesFightPacing: false,
        )
        battle.roster.enemy.currentHealth = 10
        battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 2)

        let outcome = battle.resolveHeal(HealRequest(amount: 8, target: battle.enemy, sourceActorID: battle.enemy.id))

        #expect(outcome.healthRestored == 4)
    }

    @Test func `soul sharing heals the ally on a killing leech hit`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: 10, companionHealth: 10,
            companionModifiers: CombatantTalentCatalog.profile(for: ["risen_skeleton_leech_t2_2"]), appliesFightPacing: false,
        )
        battle.roster.enemy.currentHealth = 8
        battle.roster.enemy.hasConsumedDeathsDoor = true
        let outcome = battle.resolveTestDamage(8, from: .companion, options: .effect(abilityHasLeech: true))

        #expect(outcome.healthLost == 8)
        #expect(battle.health(of: battle.enemy) == 0)
        #expect(battle.health(of: battle.hero) == 14)
        #expect(battle.health(of: battle.companion) == 14)
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(
            8, sourceActorID: battle.companion.id, target: battle.enemy,
            abilityHasLeech: true, in: &battle,
        ) }
        #expect(battle.health(of: battle.hero) == 14)
    }
}
