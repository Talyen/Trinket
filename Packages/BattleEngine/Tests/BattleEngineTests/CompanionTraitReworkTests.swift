import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct CompanionTraitReworkTests {
    @Test func faeFortuneGainsHealthWhenCleansing() throws {
        let pixie = try #require(GameContent.companions.first { $0.id == "pixie" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let pixieBuild = CombatBuildResolver.build(
            combatant: pixie,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["pixie_cleanse_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: pixieBuild.combatant,
            enemy: enemy,
            companionModifiers: pixieBuild.modifiers
        )
        context.roster.mutateRuntime(for: pixieBuild.combatant) { $0.currentHealth = 10 }
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 10 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 6, sourceActorID: enemy.id)],
            for: hero
        )

        _ = HeroCompanionTraitTestSupport.apply(
            .cleanseRandom,
            abilityName: "Cleanse",
            source: pixieBuild.combatant,
            target: hero,
            in: &context
        )

        try #expect(context.roster.health(for: pixieBuild.combatant) == 12)
        try #expect(context.roster.health(for: hero) == 10)
        try #expect(HeroCompanionTraitTestSupport.poisonPotency(on: hero, in: context) == 0)
    }

    @Test func purifyingWisdomDrawsCardWhenCleansing() throws {
        let owl = try #require(GameContent.companions.first { $0.id == "library_owl" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let owlBuild = CombatBuildResolver.build(
            combatant: owl,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["library_owl_cleanse_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
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

        let initialHandCount = context.hand.count
        _ = HeroCompanionTraitTestSupport.apply(
            .cleanseRandom,
            abilityName: "Cleanse",
            source: owlBuild.combatant,
            target: hero,
            in: &context
        )

        try #expect(context.hand.count == initialHandCount + 1)
        try #expect(HeroCompanionTraitTestSupport.poisonPotency(on: hero, in: context) == 0)
    }

    @Test func thickHideReducesDamageTaken() throws {
        // Verify passiveMitigationFlat reduces damage by 1 using a zero-toughness
        // companion so toughness DR doesn't interfere with the expected value.
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            companionModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    mitigation: MitigationTriggers(
                        passiveMitigationFlat: 1
                    )
                )
            )
        )
        context.roster.mutateRuntime(for: companion) { $0.currentHealth = 15 }
        _ = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: companion,
                keyword: .physical,
                sourceActorID: enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(context.roster.health(for: companion) == 11)
    }

    @Test func coldBloodAppliesPoisonOnDodge() throws {
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: lizard,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["lizard_scout_poison_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        _ = CombatTriggerEngine.afterDodge(by: build.combatant, attackerID: enemy.id, in: &context)

        try #expect(HeroCompanionTraitTestSupport.poisonPotency(on: enemy, in: context) == 2)
    }

    @Test func rebirthRevivesBeforeDeathsDoorThenDeathsDoorOnSecondLethal() throws {
        let phoenix = try #require(GameContent.companions.first { $0.id == "phoenix" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: phoenix,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["phoenix_deathsdoor_t1_1"]
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
            inventory: [],
            unlockedTalents: ["risen_skeleton_deathsdoor_t1_1"]
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

    @Test func arcaneReservoirGrantsBlockOnSpendMana() throws {
        let moth = try #require(GameContent.companions.first { $0.id == "mana_moth" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: moth,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["mana_moth_mana_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )

        _ = CombatTriggerEngine.afterSpendMana(by: build.combatant, amountSpent: 3, in: &context)

        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 2)
    }

    @Test func carapaceGrantsBlockEachTurn() throws {
        let scarab = try #require(GameContent.companions.first { $0.id == "shield_scarab" })
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let build = CombatBuildResolver.build(
            combatant: scarab,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["shield_scarab_block_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: hero,
            companion: build.combatant,
            enemy: enemy,
            companionModifiers: build.modifiers
        )
        _ = EffectTurnEngine.advanceAll(context: &context)

        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 2)
    }
}
