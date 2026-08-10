import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct TraitBattleTests {
    private func makeContext(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero),
            companion: CombatantRuntime(combatant: companion),
            enemy: CombatantRuntime(combatant: enemy)
        )
        return BattleState(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: .zero
        )
    }

    private func apply(
        _ effect: Effect,
        abilityName: String,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
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

    @Test func packLeaderIncreasesCompanionDamage() throws {
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let rangerBuild = CombatBuildResolver.build(
            combatant: ranger,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )

        var context = makeContext(
            hero: rangerBuild.combatant,
            companion: wolf,
            enemy: enemy,
            heroModifiers: rangerBuild.modifiers
        )

        let outcome = context.resolveDamage(
            .directAbilityHit(amount: 1, target: enemy, keyword: .physical, sourceActorID: wolf.id)
        )

        let strengthPercent = wolf.primaryStats.statDamageBonusPercent(keyword: .physical)
        let strengthBonus = CombatRounding.scaled(1, multiplier: strengthPercent)
        let packBonus = rangerBuild.modifiers.companionDamageDealtBonus
        try #expect(packBonus == 1)
        try #expect(outcome.healthLost == 1 + strengthBonus + packBonus)
    }

    @Test func purifyingWisdomDrawsCardAfterCleanse() throws {
        let owl = try #require(GameContent.companions.first { $0.id == "library_owl" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let owlBuild = CombatBuildResolver.build(
            combatant: owl,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = makeContext(
            hero: hero,
            companion: owlBuild.combatant,
            enemy: enemy,
            companionModifiers: owlBuild.modifiers
        )
        context.companionDeck.putOnBottom(.heal)
        while !context.hand.isEmpty {
            _ = context.hand.remove(id: context.hand.cards[0].id)
        }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 6, sourceActorID: enemy.id)],
            for: hero
        )

        let outcome = apply(
            .cleanse(nil),
            abilityName: "Cleanse",
            source: owlBuild.combatant,
            target: hero,
            in: &context
        )

        try #expect(outcome.didApply)
        try #expect(context.hand.count == 1)
    }

    @Test func loyalComfortHealsHeroWhenCompanionRestoresHealth() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(restoreHealthAlsoHealHero: 1)
            )
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 12 }
        context.roster.mutateRuntime(for: companion) { $0.currentHealth = 19 }

        _ = apply(
            .instantHeal(.health, 1),
            abilityName: "Apple",
            source: companion,
            target: companion,
            in: &context
        )

        try #expect(context.roster.health(for: hero) == 13)
    }
}
