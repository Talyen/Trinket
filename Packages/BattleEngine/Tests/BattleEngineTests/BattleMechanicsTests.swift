import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleMechanicsTests {
    private func makeContext(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant,
        heroMana: Int? = nil,
        enemyEffects: [ActiveEffect] = []
    ) -> BattleEngineContext {
        let heroRuntime = CombatantRuntime(
            combatant: hero,
            initialMana: heroMana
        )
        let enemyRuntime = CombatantRuntime(
            combatant: enemy,
            initialActiveEffects: enemyEffects
        )
        let roster = BattleRoster(
            hero: heroRuntime,
            pet: CombatantRuntime(combatant: pet),
            enemy: enemyRuntime
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func markedBonusAddsDamageAndConsumesMark() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(
            hero: hero,
            pet: pet,
            enemy: enemy,
            enemyEffects: [ActiveEffect(id: 1, effect: .marked(2, 6), remainingTicks: 6, sourceActorID: hero.id)]
        )

        let outcome = context.resolveDamage(
            .directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id)
        )

        try #expect(outcome.healthLost == 5)
        try #expect(
            !context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect { return true }
                return false
            }
        )
    }

    @Test func insufficientManaFallsBackToBasic() throws {
        let basic = Ability(id: "basic", name: "Basic", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "mana-skill", name: "Mana Skill", tier: .skill, directDamage: 5, description: "Skill", manaCost: 3)
        let wizard = Combatant(
            id: "wizard",
            name: "Wizard",
            role: .hero,
            maxHealth: 20,
            maxMana: 5,
            abilities: [basic, skill]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let context = makeContext(hero: wizard, pet: pet, enemy: enemy, heroMana: 0)

        let ability = BattleTurnEngine.selectedAbility(
            for: wizard,
            turnNumber: 3,
            currentMana: context.roster.runtime(for: wizard)?.currentMana ?? 0
        )

        try #expect(ability?.id == wizard.abilityLoadout.basic?.id)
    }

    @Test func predatorsHasteAppliesHasteBuff() throws {
        // Wolf lists Predator's Haste in skill choices; withAbilityLoadout resolves
        // selections against choices, so panther cannot select this skill.
        let baseWolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        let wolf = baseWolf.withAbilityLoadout(
            AbilityLoadout(
                basic: baseWolf.abilityLoadout.basic,
                skill: .predatorsHaste,
                ultimate: baseWolf.abilityLoadout.ultimate
            )
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(hero: hero, pet: wolf, enemy: enemy)
        var wolfRuntime = try #require(context.roster.runtime(for: wolf))
        wolfRuntime.actionCount = 2
        context.roster.update(wolfRuntime)
        let matchup = BattleMatchup(hero: hero, pet: wolf, enemy: enemy)

        _ = BattleTurnEngine.performAction(
            actor: wolf,
            abilityTarget: enemy,
            matchup: matchup,
            context: &context
        )

        try #expect(
            context.roster.activeEffects(for: wolf).contains { if case .haste = $0.effect { return true }; return false }
        )
    }
}
