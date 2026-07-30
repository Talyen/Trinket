import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct AffixUnderrepresentedReactionTests {
    @Test func disruptingPurgesWhenEnemyIsStunned() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(enemyStunnedPurgeCount: 1))
            )
        )
        let enemy = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatReactionEngine.afterEnemyStunned(in: &context)

        try #expect(events.contains { $0.abilityName == "Disrupting" && $0.effectKind == .purgeApplied })
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
    }

    @Test func unmakingPurgesOnCriticalHit() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(criticalPurgeCount: 1))
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatReactionEngine.afterCriticalHit(to: enemy, source: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Unmaking" && $0.effectKind == .purgeApplied })
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
    }

    @Test func arcaneWardGrantsBlockWhenGainingMana() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(gainManaBlockFlat: 2))
            )
        )
        let hero = context.roster.hero.combatant

        let events = CombatReactionEngine.afterGainMana(by: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Arcane Ward" && $0.amount == 2 })
    }

    @Test func siphoningAndBloodPriceFireOnLeech() throws {
        let source = Combatant(
            id: "source",
            name: "Source",
            role: .hero,
            maxHealth: 50,
            maxMana: 5,
            abilities: []
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: source, initialMana: 0),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: target)
            ),
            rng: SeededRandomNumberGenerator(seed: BattleTestFixtures.deterministicNonCriticalSeed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(leechRestoreManaFlat: 2, leechGoldFlat: 1))
            ),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let hero = context.roster.hero.combatant

        let events = CombatReactionEngine.afterLeech(by: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Siphoning" && $0.amount == 2 })
        try #expect(events.contains { $0.abilityName == "Blood Price" && $0.amount == 1 })
        try #expect(context.gold == 1)
        try #expect(context.roster.runtime(for: hero)?.currentMana == 2)
    }

    @Test func bountyGrantsGoldWhenEnemyIsDefeated() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(defeatEnemyGoldFlat: 4))
            )
        )

        let events = CombatReactionEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 4)
        try #expect(events.contains { $0.abilityName == "Bounty" && $0.amount == 4 })
    }

    @Test func bountyGrantsGoldFromCompanionWhenAlive() throws {
        var context = BattleTestFixtures.makePipelineContext()
        let companion = context.roster.companion.combatant
        context = BattleState(
            roster: context.roster,
            rng: context.rng,
            nextEffectID: context.nextEffectID,
            nextEventID: context.nextEventID,
            events: context.events,
            gold: context.gold,
            initialGold: context.initialGold,
            heroModifiers: .zero,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(defeatEnemyGoldFlat: 3))
            ),
            enemyModifiers: .zero
        )

        let events = CombatReactionEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 3)
        try #expect(events.contains {
            $0.abilityName == "Bounty" && $0.amount == 3 && $0.actorName == companion.name
        })
    }

    @Test func bountyGrantsCompanionGoldWhenHeroIsDead() throws {
        var context = BattleTestFixtures.makePipelineContext()
        let hero = context.roster.hero.combatant
        let companion = context.roster.companion.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 0 }
        context = BattleState(
            roster: context.roster,
            rng: context.rng,
            nextEffectID: context.nextEffectID,
            nextEventID: context.nextEventID,
            events: context.events,
            gold: context.gold,
            initialGold: context.initialGold,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(defeatEnemyGoldFlat: 4))
            ),
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(defeatEnemyGoldFlat: 3))
            ),
            enemyModifiers: .zero
        )

        let events = CombatReactionEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 3)
        try #expect(events.count == 1)
        try #expect(events.contains {
            $0.abilityName == "Bounty" && $0.amount == 3 && $0.actorName == companion.name
        })
    }

    @Test func gildedIncreasesGoldGrantedByPercent() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(goldGainedPercent: 0.10)
        )
        let hero = context.roster.hero.combatant

        try #expect(context.goldGranted(for: 10, sourceActorID: hero.id) == 11)
        context.addGold(10, sourceActorID: hero.id)
        try #expect(context.gold == 11)
    }

    @Test func sidestepAndWhiplashFireWhenDodging() throws {
        var context = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 20,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(affixReactions: .init(dodgeHealFlat: 3, dodgeDealStunFlat: 3))
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }

        let expectedHeal = context.paced(3, sourceActorID: hero.id)
        let events = CombatReactionEngine.afterDodge(by: hero, in: &context)

        try #expect(context.roster.health(for: hero) == 5 + expectedHeal)
        try #expect(events.contains { $0.abilityName == "Sidestep" && $0.amount == expectedHeal })
        try #expect(context.roster.health(for: enemy) == 17)
        try #expect(events.contains { $0.abilityName == "Whiplash" && $0.amount == 3 })
    }

    @Test func blurAddsDodgeChanceWhileBelowHealthThreshold() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    affixReactions: .init(
                        dodgeChanceBelowHealthPercentThreshold: 0.50,
                        dodgeChanceBelowHealthPercentBonus: 0.15
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 4 }
        var state = DamageResolutionState(
            amount: 1,
            combatant: hero,
            sourceActorID: "enemy",
            damageKeyword: .physical,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: true
        )

        let chance = DamagePipeline.dodgeChance(for: state, in: context)
        try #expect(abs(chance - 0.15) < 0.0001)

        context.roster.mutateRuntime(for: hero) { $0.currentHealth = $0.maxHealth }
        state = DamageResolutionState(
            amount: 1,
            combatant: hero,
            sourceActorID: "enemy",
            damageKeyword: .physical,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: true
        )
        try #expect(DamagePipeline.dodgeChance(for: state, in: context) == 0)
    }
}
