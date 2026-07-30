import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CompanionTraitReworkTests {
    @Test func faeFortuneCleansesWhenHealing() throws {
        let pixie = try #require(GameContent.companions.first { $0.id == "pixie" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let pixieBuild = CombatBuildResolver.build(
            combatant: pixie,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: pixieBuild.combatant,
            enemy: enemy,
            companionModifiers: pixieBuild.modifiers
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 6, sourceActorID: enemy.id)],
            for: hero
        )

        _ = HeroCompanionTraitTestSupport.apply(
            .instantHeal(.health, 1),
            abilityName: "Heal",
            source: pixieBuild.combatant,
            target: hero,
            in: &context
        )

        try #expect(context.roster.health(for: hero) == 11)
        try #expect(HeroCompanionTraitTestSupport.poisonPotency(on: hero, in: context) == 0)
    }

    @Test func faeFortuneSuppressedHealDoesNotCleanse() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(healCleanseCount: 1)
            )
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 6, sourceActorID: enemy.id)],
            for: hero
        )

        _ = HealingEngine.resolveHeal(
            HealRequest(
                amount: 1,
                target: hero,
                sourceActorID: companion.id,
                logAs: .silent,
                suppressTraitReactions: true
            ),
            in: &context
        )

        try #expect(HeroCompanionTraitTestSupport.poisonPotency(on: hero, in: context) == 2)
    }

    @Test func thickHideRestoresHealthEachTurn() throws {
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: bear,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 10 }
        let matchup = BattleMatchup(hero: hero, companion: build.combatant, enemy: enemy)

        _ = EffectTurnEngine.advanceAll(context: &context, matchup: matchup)

        try #expect(context.roster.health(for: build.combatant) == 11)
    }

    @Test func coldBloodAppliesPoisonOnDodge() throws {
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: lizard,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        _ = CombatReactionEngine.afterDodge(by: build.combatant, in: &context)

        try #expect(HeroCompanionTraitTestSupport.poisonPotency(on: enemy, in: context) == 2)
    }

    @Test func rebirthRevivesBeforeDeathsDoorThenDeathsDoorOnSecondLethal() throws {
        let phoenix = try #require(GameContent.companions.first { $0.id == "phoenix" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: phoenix,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 10)
        try #expect(context.roster.runtime(for: build.combatant)?.hasTriggeredDeathRevive == true)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant) == false)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant))
        try #expect(context.roster.isDeathsDoorActive(for: build.combatant))
    }

    @Test func deathrattleRevivesWithBlockBeforeDeathsDoor() throws {
        let skeleton = try #require(GameContent.companions.first { $0.id == "risen_skeleton" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: skeleton,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 5 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(
            HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context)
                == context.paced(10, sourceActorID: build.combatant.id)
        )
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant) == false)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 50,
                target: build.combatant,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(context.roster.health(for: build.combatant) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: build.combatant))
    }

    @Test func bountyGrantsGoldOnEnemyDefeat() throws {
        let retriever = try #require(GameContent.companions.first { $0.id == "golden_retriever" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: retriever,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        let events = CombatReactionEngine.afterEnemyDefeated(in: &context)

        try #expect(context.gold == 3)
        try #expect(events.contains { $0.abilityName == "Bounty" && $0.amount == 3 })
    }

    @Test func arcaneReservoirGrantsBlockOnSpendMana() throws {
        let moth = try #require(GameContent.companions.first { $0.id == "mana_moth" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: moth,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        _ = CombatReactionEngine.afterSpendMana(by: build.combatant, in: &context)

        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 1)
    }

    @Test func carapaceGrantsBlockEachTurn() throws {
        let scarab = try #require(GameContent.companions.first { $0.id == "shield_scarab" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: scarab,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        let matchup = BattleMatchup(hero: hero, companion: build.combatant, enemy: enemy)

        _ = EffectTurnEngine.advanceAll(context: &context, matchup: matchup)

        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 1)
    }
}
