import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HeroTraitReworkTests {
    @Test func oathboundGrantsBlockOnHolyAndStunDamage() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["knight_holy_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .holy,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 2)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .stun,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 4)
    }

    @Test func cutpurseGrantsGoldOnCriticalHit() throws {
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: rogue,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["rogue_gold_t1_1"]
        )
        var critContext = HeroCompanionTraitTestSupport.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )
        var nonCritContext = HeroCompanionTraitTestSupport.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )

        _ = critContext.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .physical,
                sourceActorID: build.combatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: false,
                    applyDodge: false,
                    guaranteedCritical: true
                )
            )
        )
        _ = nonCritContext.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .physical,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(critContext.gold == 2)
        try #expect(nonCritContext.gold == 0)
    }

    @Test func arcaneFocusAppliesRandomBurnOrFreezeOnSpendMana() throws {
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: wizard,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["wizard_mana_t1_1"]
        )

        var burnSeen = false
        var freezeSeen = false
        for seed in UInt64(0) ..< 64 {
            var context = HeroCompanionTraitTestSupport.makeContext(
                hero: build.combatant,
                companion: companion,
                enemy: enemy,
                heroModifiers: build.modifiers,
                seed: seed
            )
            _ = CombatTriggerEngine.afterSpendMana(by: build.combatant, amountSpent: 3, in: &context)
            let effects = context.roster.activeEffects(for: enemy)
            let hasBurn = effects.contains { active in
                if case .burn = active.effect {
                    return true
                }
                return false
            }
            if hasBurn {
                burnSeen = true
            }
            let hasFreezeMeter = effects.contains { $0.effect.keyword == .freeze }
            if hasFreezeMeter {
                freezeSeen = true
            }
            if burnSeen, freezeSeen {
                break
            }
        }

        try #expect(burnSeen)
        try #expect(freezeSeen)
    }

    @Test func bloodfireHealsOnBurnDamage() throws {
        let warlock = try #require(GameContent.heroes.first { $0.id == "warlock" })
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: warlock,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["warlock_burn_t1_1"]
        )
        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: build.combatant,
            companion: companion,
            enemy: enemy,
            heroModifiers: build.modifiers
        )
        context.roster.mutateRuntime(for: build.combatant) { $0.currentHealth = 10 }

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .burn,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(context.roster.health(for: build.combatant) == 12)
    }

    @Test func packLeaderIncreasesCompanionBleedDamage() throws {
        let ranger = try #require(GameContent.heroes.first { $0.id == "ranger" })
        let wolf = try #require(GameContent.companions.first { $0.id == "wolf" })
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let rangerBuild = CombatBuildResolver.build(
            combatant: ranger,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: ["ranger_bleed_t1_1"]
        )

        var context = HeroCompanionTraitTestSupport.makeContext(
            hero: rangerBuild.combatant,
            companion: wolf,
            enemy: enemy,
            heroModifiers: rangerBuild.modifiers
        )

        // Bleed damage receives pack bonus
        let bleedOutcome = context.resolveDamage(
            .directAbilityHit(amount: 1, target: enemy, keyword: .bleed, sourceActorID: wolf.id)
        )
        let bleedPackBonus = rangerBuild.modifiers.companionBleedDamageDealtBonus
        try #expect(bleedPackBonus == 3)
        try #expect(bleedOutcome.healthLost == 1 + bleedPackBonus)

        // Physical damage does not receive pack bleed bonus
        let physicalOutcome = context.resolveDamage(
            .directAbilityHit(amount: 1, target: enemy, keyword: .physical, sourceActorID: wolf.id)
        )
        let strengthPercent = wolf.primaryStats.statDamageBonusPercent(keyword: .physical)
        let strengthBonus = CombatRounding.scaled(1, multiplier: strengthPercent)
        try #expect(physicalOutcome.healthLost == 1 + strengthBonus)
    }
}
