import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleMechanicsTests {
    private func makeContext(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroMana: Int? = nil,
        enemyEffects: [ActiveEffect] = []
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: enemyEffects
        )
        if let heroMana {
            battle.roster.hero.currentMana = heroMana
        }
        return battle
    }

    @Test func markedBonusAddsDamageAndConsumesMark() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEffects: [ActiveEffect(id: 1, effect: .marked(2, 6), remainingTurns: 6, sourceActorID: hero.id)]
        )

        let outcome = context.resolveDamage(
            .directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id)
        )

        try #expect(outcome.healthLost == 5)
        try #expect(
            !context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect {
                    return true
                }
                return false
            }
        )
    }

    @Test func predatorsFocusAppliesCriticalChanceBonus() throws {
        let baseWolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let wolf = baseWolf.withAbilityLoadout(
            AbilityLoadout(
                basic: baseWolf.abilityLoadout.basic,
                skill: .predatorsFocus,
                ultimate: baseWolf.abilityLoadout.ultimate
            )
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(hero: hero, companion: wolf, enemy: enemy)
        let ability = try #require(wolf.abilityLoadout.skill)

        _ = BattleTurnEngine.performAction(
            ability: ability,
            actor: wolf,
            abilityTarget: context.enemy,
            context: &context
        )

        try #expect(
            context.roster.activeEffects(for: wolf).contains {
                if case .nextStrikeCritical = $0.effect {
                    return true
                }
                return false
            }
        )
    }

    @Test func nextStrikeCriticalGuaranteesCritAndConsumes() throws {
        let ability = Ability(
            id: "test-crit-strike",
            name: "Test Crit Strike",
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
                    initialActiveEffects: [ActiveEffect(id: 1, effect: .nextStrikeCritical, remainingTurns: 0)]
                ),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: BattleTestFixtures.deterministicNonCriticalSeed),
            nextEffectID: 2,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        let events = BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context
        )

        let damageEvent = try #require(events.first { $0.kind == .abilityDamage })
        try #expect(damageEvent.isCritical)
        try #expect(!(context.roster.activeEffects(for: hero).contains {
            if case .nextStrikeCritical = $0.effect {
                return true
            }
            return false
        }))
    }
}
