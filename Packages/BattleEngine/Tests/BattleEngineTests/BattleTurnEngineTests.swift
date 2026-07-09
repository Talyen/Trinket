import Testing
import TrinketTestSupport
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleTurnEngineTests {
    private func makeContext(
        actorEffects: [ActiveEffect] = [],
        seed: UInt64 = 1772
    ) -> (context: BattleEngineContext, matchup: BattleMatchup) {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: pet, initialActiveEffects: []),
            enemy: CombatantRuntime(combatant: enemy, initialActiveEffects: actorEffects)
        )
        let context = BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
        return (context, BattleMatchup(hero: hero, pet: pet, enemy: enemy))
    }

    @Test func consumeActionSkipEmitsControlActionSkippedAndRemovesEffect() throws {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        let enemy = context.roster.enemy.combatant

        let events = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        try #expect(events.count == 1)
        try #expect(events[0].effectKind == .controlActionSkipped)
        try #expect(events[0].keyword == .stun)
        try #expect(!(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
    }

    @Test func consumeActionSkipRecordsActionForScheduling() throws {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        let enemy = context.roster.enemy.combatant
        let before = try #require(context.roster.runtime(for: enemy)?.actionCount)

        _ = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        try #expect(try #require(context.roster.runtime(for: enemy)?.actionCount) == before + 1)
        try #expect(context.actionCount == 1)
    }

    @Test func actPerformsAbilityWhenNoSkipPending() throws {
        var (context, matchup) = makeContext()
        let enemy = context.roster.enemy.combatant

        let events = BattleTurnEngine.act(actor: enemy, matchup: matchup, context: &context)

        try #expect(events.contains { $0.kind == .ability })
        try #expect(!(events.contains { $0.effectKind == .controlActionSkipped }))
    }

    @Test func deathgripDoesNotFireOnSkippedAction() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, actionIntervalTicks: 100)
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(
                    combatant: hero,
                    initialActiveEffects: [
                        ActiveEffect(id: 1, effect: .deathsDoor, remainingTicks: 4),
                        ActiveEffect(id: 2, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
                    ],
                    hasConsumedDeathsDoor: true
                ),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 3,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(blockPerActionWhileDeathsDoor: 2),
            petModifiers: .zero,
            enemyModifiers: .zero
        )
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        let events = BattleTurnEngine.act(actor: hero, matchup: matchup, context: &context)

        try #expect(events.contains { $0.effectKind == .controlActionSkipped })
        try #expect(!events.contains { $0.abilityName == "Deathgrip" })
        try #expect(
            !context.roster.activeEffects(for: hero).contains { if case .shield = $0.effect { return true }; return false }
        )
    }

    @Test func abilityEventIncludesActorAbilityAndTier() throws {
        var (context, matchup) = makeContext()
        let enemy = context.roster.enemy.combatant

        let events = BattleTurnEngine.act(actor: enemy, matchup: matchup, context: &context)
        let abilityEvent = try #require(events.first { $0.kind == .ability })

        #expect(abilityEvent.actorID == enemy.id)
        #expect(abilityEvent.abilityID == Ability.slash.id)
        #expect(abilityEvent.abilityName == Ability.slash.name)
        #expect(abilityEvent.abilityTier == Ability.slash.tier)
    }

    @Test func performActionSkipsCorpseTargetedEffectsAfterLethalHit() throws {
        let killAndMark = Ability(
            id: "kill-mark",
            name: "Kill Mark",
            tier: .basic,
            directDamage: 100,
            damageKeyword: .physical,
            effects: [.marked(2, 4)]
        )
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 2,
            abilities: [killAndMark]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 5,
            actionIntervalTicks: 100
        )
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        let events = BattleTurnEngine.performAction(
            actor: hero,
            abilityTarget: enemy,
            matchup: matchup,
            context: &context
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(!(context.roster.activeEffects(for: enemy).contains { if case .marked = $0.effect { return true }; return false }))
        let abilityEvent = try #require(events.first { $0.kind == .ability })
        try #expect(!(abilityEvent.appliedEffectSummaries.contains { $0.localizedCaseInsensitiveContains("mark") }))
    }

    @Test func performActionStillGrantsGoldAfterLethalHit() throws {
        let killAndGold = Ability(
            id: "kill-gold",
            name: "Kill Gold",
            tier: .basic,
            directDamage: 100,
            damageKeyword: .physical,
            effects: [.resourceGain(.gold, 3)]
        )
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 2,
            abilities: [killAndGold]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 5,
            actionIntervalTicks: 100
        )
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: enemy)

        _ = BattleTurnEngine.performAction(
            actor: hero,
            abilityTarget: enemy,
            matchup: matchup,
            context: &context
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(context.gold == 3)
    }
}
