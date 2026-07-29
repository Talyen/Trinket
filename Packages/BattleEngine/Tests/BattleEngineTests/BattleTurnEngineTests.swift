import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct BattleTurnEngineTests {
    private func makeContext(
        actorEffects: [ActiveEffect] = [],
        seed: UInt64 = 1772
    ) -> (context: BattleState, matchup: BattleMatchup) {
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
        let context = BattleState(
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

    @Test func consumeActionSkipEmitsEventRemovesEffectAndRecordsAction() throws {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
        ])
        let enemy = context.roster.enemy.combatant
        let before = try #require(context.roster.runtime(for: enemy)?.actionCount)

        let events = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        try #expect(events.contains { $0.effectKind == .controlActionSkipped && $0.keyword == .stun })
        try #expect(!(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
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

    @Test func deathgripGrantsBlockWhenEnteringDeathsDoor() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            maxHealth: 50,
            abilities: [.slash]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero, initialHealth: 5),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(blockOnDeathsDoor: 8)),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )

        let (_, events) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(events.contains { $0.effectKind == .deathsDoorTriggered })
        try #expect(events.contains { $0.abilityName == "Deathgrip" && $0.amount == 8 })
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(
            context.roster.activeEffects(for: hero).contains {
                if case let .shield(keyword, points) = $0.effect {
                    return keyword == .block && points == 8
                }
                return false
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

    @Test func nextStrikeDoubleDoublesOutgoingDamageAndConsumes() throws {
        let ability = Ability(
            id: "test-strike",
            name: "Test Strike",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical)]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(
                    combatant: hero,
                    initialActiveEffects: [ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0)]
                ),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 2,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let matchup = BattleMatchup(hero: hero, companion: companion, enemy: enemy)
        let healthBefore = context.roster.health(for: enemy)

        let events = BattleTurnEngine.performAbility(
            ability,
            actor: hero,
            matchup: matchup,
            context: &context
        )

        let damageEvent = try #require(events.first { $0.kind == .abilityDamage })
        try #expect(damageEvent.amount == 4)
        try #expect(context.roster.health(for: enemy) == healthBefore - 4)
        try #expect(!(context.roster.activeEffects(for: hero).contains {
            if case .nextStrikeDouble = $0.effect {
                return true
            }
            return false
        }))
    }

    @Test func mixedDamageComponentsEmitExactFeedbackEventsAndOneLogSummary() {
        let ability = Ability(
            id: "mixed-strike",
            name: "Mixed Strike",
            tier: .basic,
            damageComponents: [
                DamageComponent(2, keyword: .physical),
                DamageComponent(2, keyword: .burn),
            ]
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
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
            ability,
            actor: hero,
            matchup: matchup,
            context: &context
        )

        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 2)
        #expect(components.map(\.keyword) == [.physical, .burn])
        #expect(components.allSatisfy { $0.amount > 0 })
        #expect(Set(components.map(\.actionID)).count == 1)
        #expect(events.count { $0.kind == .ability } == 1)
        #expect(BattleLogReducer.entries(from: events, matchup: matchup).count == 1)
    }

    @Test func criticalMetadataBelongsToExactDamageComponent() throws {
        let ability = Ability(
            id: "critical-strike",
            name: "Critical Strike",
            tier: .basic,
            directDamage: 3,
            guaranteedCriticalIfEnemyBuffed: true
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(
                    combatant: enemy,
                    initialActiveEffects: [
                        ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 2),
                    ]
                )
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
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
            ability,
            actor: hero,
            matchup: matchup,
            context: &context
        )

        let component = try #require(events.first { $0.kind == .abilityDamage })
        #expect(component.isCritical)
        #expect(!events.contains { $0.effectKind != nil && $0.abilityName == "Critical" })
    }

    @Test(arguments: [true, false])
    func performAbilityAfterLethalHitSkipsCorpseEffectsButStillGrantsGold(grantGold: Bool) throws {
        let ability = Ability(
            id: grantGold ? "kill-gold" : "kill-mark",
            name: grantGold ? "Kill Gold" : "Kill Mark",
            tier: .basic,
            directDamage: 100,
            damageKeyword: .physical,
            effects: grantGold ? [.resourceGain(.gold, 3)] : [.marked(2, 4)]
        )
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [ability]
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 5
        )
        var context = BattleState(
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
            ability,
            actor: hero,
            matchup: matchup,
            context: &context
        )

        try #expect(context.roster.health(for: enemy) == 0)
        if grantGold {
            try #expect(context.gold == 3)
        } else {
            try #expect(!(context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect {
                    return true
                }
                return false
            }))
            let abilityEvent = try #require(events.first { $0.kind == .ability })
            try #expect(!(abilityEvent.appliedEffectSummaries.contains {
                $0.localizedCaseInsensitiveContains("mark")
            }))
        }
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
