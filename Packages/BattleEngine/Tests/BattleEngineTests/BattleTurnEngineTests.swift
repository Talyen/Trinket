import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct BattleTurnEngineTests {
    private func makeContext(
        actorEffects: [ActiveEffect] = [],
        seed: UInt64 = 1772
    ) -> (context: BattleEngineContext, matchup: BattleMatchup) {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            abilities: [.slash]
        )
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: companion, initialActiveEffects: []),
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
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        return (context, BattleMatchup(hero: hero, companion: companion, enemy: enemy))
    }

    @Test func consumeActionSkipEmitsControlActionSkippedAndRemovesEffect() throws {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        let enemy = context.roster.enemy.combatant

        let events = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        try #expect(events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == .stun })
        try #expect(!(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
    }

    @Test func consumeActionSkipRecordsAction() throws {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        let enemy = context.roster.enemy.combatant
        let before = try #require(context.roster.runtime(for: enemy)?.actionCount)

        _ = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        try #expect(try #require(context.roster.runtime(for: enemy)?.actionCount) == before + 1)
        try #expect(context.actionCount == 1)
    }

    @Test func performAbilityResolvesWhenNoSkipPending() throws {
        var (context, matchup) = makeContext()
        let enemy = context.roster.enemy.combatant
        let ability = try #require(enemy.abilityLoadout.basic)

        let events = BattleTurnEngine.performAbility(
            ability,
            actor: enemy,
            matchup: matchup,
            context: &context
        )

        try #expect(events.contains { $0.kind == .ability })
        try #expect(!(events.contains { $0.effectKind == .controlActionSkipped }))
    }

    @Test func deathgripDoesNotFireOnSkippedAction() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
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
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 3,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(blockPerActionWhileDeathsDoor: 2),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )

        let events = BattleTurnEngine.consumeActionSkip(for: hero, context: &context)

        try #expect(events.contains { $0.effectKind == .controlActionSkipped })
        try #expect(!events.contains { $0.abilityName == "Deathgrip" })
        try #expect(
            !context.roster.activeEffects(for: hero).contains {
                if case .shield = $0.effect {
                    return true
                }; return false
            }
        )
    }

    @Test func abilityEventIncludesActorAbilityAndTier() throws {
        var (context, matchup) = makeContext()
        let enemy = context.roster.enemy.combatant
        let ability = try #require(enemy.abilityLoadout.basic)

        let events = BattleTurnEngine.performAbility(
            ability,
            actor: enemy,
            matchup: matchup,
            context: &context
        )
        let abilityEvent = try #require(events.first { $0.kind == .ability })

        #expect(abilityEvent.actorID == enemy.id)
        #expect(abilityEvent.abilityID == Ability.slash.id)
        #expect(abilityEvent.abilityName == Ability.slash.name)
        #expect(abilityEvent.abilityTier == Ability.slash.tier)
    }

    @Test func performAbilitySkipsCorpseTargetedEffectsAfterLethalHit() throws {
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
            abilities: [killAndMark]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 5
        )
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let matchup = BattleMatchup(hero: hero, companion: companion, enemy: enemy)

        let events = BattleTurnEngine.performAbility(
            killAndMark,
            actor: hero,
            matchup: matchup,
            context: &context
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(!(context.roster.activeEffects(for: enemy).contains {
            if case .marked = $0.effect {
                return true
            }; return false
        }))
        let abilityEvent = try #require(events.first { $0.kind == .ability })
        try #expect(!(abilityEvent.appliedEffectSummaries.contains { $0.localizedCaseInsensitiveContains("mark") }))
    }

    @Test func performAbilityStillGrantsGoldAfterLethalHit() throws {
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
            abilities: [killAndGold]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 5
        )
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let matchup = BattleMatchup(hero: hero, companion: companion, enemy: enemy)

        _ = BattleTurnEngine.performAbility(
            killAndGold,
            actor: hero,
            matchup: matchup,
            context: &context
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(context.gold == 3)
    }

    @Test func preferredTierFollowsEnemyCadence() throws {
        try #expect(BattleTurnEngine.preferredTier(for: 1) == .basic)
        try #expect(BattleTurnEngine.preferredTier(for: 2) == .basic)
        try #expect(BattleTurnEngine.preferredTier(for: 3) == .skill)
        try #expect(BattleTurnEngine.preferredTier(for: 6) == .ultimate)
        try #expect(BattleTurnEngine.preferredTier(for: 9) == .skill)
        try #expect(BattleTurnEngine.preferredTier(for: 12) == .ultimate)

        let basic = Ability(id: "basic", name: "Basic", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "skill", name: "Skill", tier: .skill, directDamage: 5, description: "Skill")
        let ultimate = Ability(id: "ult", name: "Ult", tier: .ultimate, directDamage: 9, description: "Ult")
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 30,
            abilities: [basic, skill, ultimate]
        )
        try #expect(BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: 3)?.id == skill.id)
        try #expect(BattleTurnEngine.selectedEnemyAbility(for: enemy, turnNumber: 6)?.id == ultimate.id)
    }
}
