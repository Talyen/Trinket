import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct AffixUnderrepresentedReactionTests {
    @Test func disruptingPurgesWhenEnemyIsStunned() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(
                        enemyStunnedPurgeCount: 1
                    )
                )
            )
        )
        let enemy = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatTriggerEngine.afterEnemyStunned(in: &context)

        try #expect(events.contains { $0.abilityName == "Disrupting" && $0.effectKind == .purgeApplied })
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
    }

    @Test func unmakingPurgesOnCriticalHit() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    attack: AttackTriggers(
                        criticalPurgeCount: 1
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 2, effect: .criticalChanceBonus(0.5, 4), remainingTurns: 4, sourceActorID: enemy.id)],
            for: enemy
        )

        let events = CombatTriggerEngine.afterCriticalHit(to: enemy, source: hero, in: &context)

        try #expect(events.contains { $0.abilityName == "Unmaking" && $0.effectKind == .purgeApplied })
        try #expect(!context.roster.activeEffects(for: enemy).map(\.effect).contains(where: \.isRemovableBuff))
    }

    @Test func arcaneWardGrantsBlockWhenGainingMana() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mana: ManaTriggers(
                        gainManaBlockFlat: 2
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant

        let events = CombatTriggerEngine.afterGainMana(by: hero, in: &context)

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
                triggers: CombatTraitTriggers(
                    mana: ManaTriggers(
                        leechRestoreManaFlat: 2
                    ),
                    gold: GoldTriggers(
                        leechGoldFlat: 1
                    )
                )
            ),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let hero = context.roster.hero.combatant

        let events = CombatTriggerEngine.afterLeech(by: hero, target: context.roster.enemy.combatant, in: &context)

        try #expect(events.contains { $0.abilityName == "Siphoning" && $0.amount == 2 })
        try #expect(events.contains { $0.abilityName == "Blood Price" && $0.amount == 1 })
        try #expect(context.gold == 1)
        try #expect(context.roster.runtime(for: hero)?.currentMana == 2)
    }

    @Test func bountyGrantsGoldWhenEnemyIsDefeated() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 4
                    )
                )
            )
        )

        let events = CombatTriggerEngine.afterEnemyDefeated(in: &context)

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
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 3
                    )
                )
            ),
            enemyModifiers: .zero
        )

        let events = CombatTriggerEngine.afterEnemyDefeated(in: &context)

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
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 4
                    )
                )
            ),
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        defeatEnemyGoldFlat: 3
                    )
                )
            ),
            enemyModifiers: .zero
        )

        let events = CombatTriggerEngine.afterEnemyDefeated(in: &context)

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
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(
                        dodgeDealStunFlat: 3
                    ),
                    dodge: DodgeTriggers(
                        dodgeHealFlat: 3
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }

        let expectedHeal = context.paced(3, sourceActorID: hero.id)
        let events = CombatTriggerEngine.afterDodge(by: hero, attackerID: context.roster.enemy.id, in: &context)

        try #expect(context.roster.health(for: hero) == 5 + expectedHeal)
        try #expect(events.contains { $0.abilityName == "Sidestep" && $0.amount == expectedHeal })
        try #expect(context.roster.health(for: enemy) == 17)
        try #expect(events.contains { $0.abilityName == "Whiplash" && $0.amount == 3 })
    }

    @Test func blurAddsDodgeChanceWhileBelowHealthThreshold() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dodge: DodgeTriggers(
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

    @Test func windfallHealsWhenPaydayGrantsGold() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dodge: DodgeTriggers(
                        dodgeGoldFlat: 2
                    ),
                    gold: GoldTriggers(
                        gainGoldBonusHealSelf: 3
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 5 }

        let events = CombatTriggerEngine.afterDodge(by: hero, attackerID: context.roster.enemy.id, in: &context)

        try #expect(context.gold == 2)
        try #expect(context.roster.health(for: hero) == 5 + context.paced(3, sourceActorID: hero.id))
        try #expect(events.contains { $0.abilityName == "Payday" && $0.amount == 2 })
        try #expect(events.contains {
            $0.effectKind == .instantHeal && $0.amount == context.paced(3, sourceActorID: hero.id)
        })
    }

    @Test func cauterizeDealsBurnDamageWithoutApplyingBurn() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(
                        onBurnApplyPoison: 1,
                        onBleedDealBurnDamage: 1
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant
        let healthBefore = context.roster.health(for: enemy)

        let events = CombatTriggerEngine.afterBleedApplied(
            to: enemy,
            sourceActorID: hero.id,
            in: &context
        )

        try #expect(context.roster.health(for: enemy) == healthBefore - 1)
        try #expect(events.contains { $0.keyword == Keyword.burn && $0.amount == 1 })
        try #expect(!context.roster.activeEffects(for: enemy).contains { $0.keyword == Keyword.burn })
        try #expect(!context.roster.activeEffects(for: enemy).contains { $0.keyword == Keyword.poison })
    }

    @Test func ashenWakeAppliesPoisonWhenBurnIsApplied() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(
                        onBurnApplyPoison: 1
                    )
                )
            )
        )
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant

        let events = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .burn,
            to: enemy,
            sourceActorID: hero.id,
            in: &context
        )

        let poison = context.roster.activeEffects(for: enemy).first { $0.keyword == .poison }
        try #expect(poison?.effect.potency == 1)
        try #expect(events.contains { $0.keyword == .poison })

        let poisonEvents = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .poison,
            to: enemy,
            sourceActorID: hero.id,
            in: &context
        )
        try #expect(poisonEvents.isEmpty)
        try #expect(context.roster.activeEffects(for: enemy).count(where: { $0.keyword == .poison }) == 1)
        try #expect(
            context.roster.activeEffects(for: enemy).first { $0.keyword == .poison }?.effect.potency == 1
        )
    }
}
