import Testing
@testable import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct TraitBattleTests {
    private func makeContext(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant,
        heroModifiers: CombatModifierProfile = .zero,
        petModifiers: CombatModifierProfile = .zero
    ) -> BattleEngineContext {
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero),
            pet: CombatantRuntime(combatant: pet),
            enemy: CombatantRuntime(combatant: enemy)
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            petModifiers: petModifiers,
            enemyModifiers: .zero
        )
    }

    private func apply(
        _ effect: Effect,
        abilityName: String,
        source: Combatant,
        target: Combatant,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        let ability = Ability(
            id: "test-\(abilityName)",
            name: abilityName,
            tier: .basic,
            targetedEffects: [TargetedEffect(effect)]
        )
        guard let handler = EffectHandlers.handler(for: effect.kind) else {
            preconditionFailure("Missing handler for \(effect.kind)")
        }
        return handler.apply(
            effect,
            ability: ability,
            source: source,
            target: target,
            action: ActionApplyContext(),
            in: &context
        )
    }

    @Test func packLeaderIncreasesPetDamage() throws {
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        let wolf = try #require(GameContent.pets.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let rangerBuild = CombatBuildResolver.build(
            combatant: ranger,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )

        var context = makeContext(
            hero: rangerBuild.combatant,
            pet: wolf,
            enemy: enemy,
            heroModifiers: rangerBuild.modifiers
        )

        let outcome = context.resolveDamage(
            .directAbilityHit(amount: 1, target: enemy, keyword: .physical, sourceActorID: wolf.id)
        )

        #expect(outcome.healthLost == 3)
    }

    @Test func purifyingWisdomHealsAfterCleanse() throws {
        let owl = try #require(GameContent.pets.first { $0.id == "library_owl" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let owlBuild = CombatBuildResolver.build(
            combatant: owl,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = makeContext(
            hero: hero,
            pet: owlBuild.combatant,
            enemy: enemy,
            petModifiers: owlBuild.modifiers
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTicks: 6, sourceActorID: enemy.id)],
            for: hero
        )

        let outcome = apply(
            .cleanse(nil),
            abilityName: "Cleanse",
            source: owlBuild.combatant,
            target: hero,
            in: &context
        )

        #expect(outcome.didApply)
        #expect(context.roster.health(for: hero) == 11)
    }

    @Test func faeFortuneHealsWhenGainingGold() throws {
        let pixie = try #require(GameContent.pets.first { $0.id == "pixie" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let pixieBuild = CombatBuildResolver.build(
            combatant: pixie,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = makeContext(
            hero: hero,
            pet: pixieBuild.combatant,
            enemy: enemy,
            petModifiers: pixieBuild.modifiers
        )
        context.roster.mutateRuntime(for: pixieBuild.combatant) {
            $0.currentHealth = pixieBuild.effectiveMaxHealth - 2
        }

        _ = apply(
            .resourceGain(.gold, 1),
            abilityName: "Gold",
            source: pixieBuild.combatant,
            target: pixieBuild.combatant,
            in: &context
        )

        #expect(
            context.roster.health(for: pixieBuild.combatant) == pixieBuild.effectiveMaxHealth
        )
    }

    @Test func loyalComfortHealsHeroWhenPetRestoresHealth() throws {
        let retriever = try #require(GameContent.pets.first { $0.id == "golden_retriever" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let retrieverBuild = CombatBuildResolver.build(
            combatant: retriever,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = makeContext(
            hero: hero,
            pet: retrieverBuild.combatant,
            enemy: enemy,
            petModifiers: retrieverBuild.modifiers
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 12 }
        context.roster.mutateRuntime(for: retrieverBuild.combatant) { $0.currentHealth = retrieverBuild.effectiveMaxHealth - 1 }

        _ = apply(
            .instantHeal(.health, 1),
            abilityName: "Apple",
            source: retrieverBuild.combatant,
            target: retrieverBuild.combatant,
            in: &context
        )

        #expect(context.roster.health(for: hero) == 13)
    }
}
