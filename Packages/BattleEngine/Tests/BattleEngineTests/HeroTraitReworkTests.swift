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
            inventory: []
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
        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 1)

        _ = context.resolveDamage(
            DamageRequest(
                amount: 3,
                target: enemy,
                keyword: .stun,
                sourceActorID: build.combatant.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        try #expect(HeroCompanionTraitTestSupport.shieldPoints(for: build.combatant, in: context) == 2)
    }

    @Test func cutpurseGrantsGoldOnCriticalHit() throws {
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: rogue,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
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

        try #expect(critContext.gold == 1)
        try #expect(nonCritContext.gold == 0)
    }

    @Test func arcaneFocusAppliesRandomBurnOrFreezeOnSpendMana() throws {
        let wizard = try #require(GameContent.heroes.first { $0.id == "wizard" })
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        let build = CombatBuildResolver.build(
            combatant: wizard,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
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
            let beforeHP = context.roster.health(for: enemy)
            _ = CombatTriggerEngine.afterSpendMana(by: build.combatant, in: &context)
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
            if context.roster.health(for: enemy) < beforeHP, !hasBurn {
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
            inventory: []
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

        try #expect(context.roster.health(for: build.combatant) == 11)
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

        var context = HeroCompanionTraitTestSupport.makeContext(
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
}
