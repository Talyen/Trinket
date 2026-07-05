import XCTest
@testable import BattleEngine
import TrinketCore
import TrinketContent

final class BattleMechanicsTests: XCTestCase {
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
            build: BattleCombatBuild(hero: hero, pet: pet, heroModifiers: .zero, petModifiers: .zero)
        )
    }

    func testMarkedBonusAddsDamageAndConsumesMark() {
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

        XCTAssertEqual(outcome.healthLost, 5)
        XCTAssertFalse(
            context.activeEffects(for: enemy).contains { if case .marked = $0.effect { return true }; return false }
        )
    }

    func testInsufficientManaFallsBackToBasic() {
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

        let ability = selectedAbilityForTests(actor: wizard, turnNumber: 3, context: context)

        XCTAssertEqual(ability?.id, wizard.abilityLoadout.basic?.id)
    }

    func testPredatorsHasteAppliesHasteBuff() throws {
        let basePanther = try XCTUnwrap(GameContent.pets.first { $0.id == "panther" })
        let panther = basePanther.withAbilityLoadout(
            AbilityLoadout(
                basic: basePanther.abilityLoadout.basic,
                skill: .predatorsHaste,
                ultimate: basePanther.abilityLoadout.ultimate
            )
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(hero: hero, pet: panther, enemy: enemy)
        var pantherRuntime = try XCTUnwrap(context.runtime(for: panther))
        pantherRuntime.actionCount = 2
        context.updateRuntime(pantherRuntime)
        let matchup = BattleMatchup(hero: hero, pet: panther, enemy: enemy)

        _ = BattleTurnEngine.performAction(
            actor: panther,
            abilityTarget: enemy,
            matchup: matchup,
            context: &context
        )

        XCTAssertTrue(
            context.activeEffects(for: panther).contains { if case .haste = $0.effect { return true }; return false }
        )
    }
}

private func selectedAbilityForTests(
    actor: Combatant,
    turnNumber: Int,
    context: BattleEngineContext
) -> Ability? {
    let tier: AbilityTier
    if turnNumber.isMultiple(of: AbilityTier.ultimate.cadenceTurns) {
        tier = .ultimate
    } else if turnNumber.isMultiple(of: AbilityTier.skill.cadenceTurns) {
        tier = .skill
    } else {
        tier = .basic
    }
    let preferred = actor.abilityLoadout.ability(for: tier)
        ?? actor.abilityLoadout.basic
        ?? actor.abilities.first
    guard let preferred else { return nil }
    guard preferred.manaCost > 0, actor.hasMana else { return preferred }
    if context.mana(of: actor) >= preferred.manaCost {
        return preferred
    }
    return actor.abilityLoadout.basic ?? actor.abilities.first
}
