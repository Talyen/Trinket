import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct EnemyTraitBattleTests {
    private func enemyBuild(id: String) throws -> CombatBuild {
        let enemy = try #require(GameContent.enemy(matching: id))
        return CombatBuildResolver.build(enemy: enemy)
    }

    private func makeContext(
        hero: Combatant,
        companion: Combatant,
        enemyBuild: CombatBuild
    ) -> BattleState {
        BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemyBuild.combatant,
            enemyModifiers: enemyBuild.modifiers
        )
    }

    @Test func skeletonTakesExtraHolyDamage() throws {
        let skeleton = try enemyBuild(id: "skeleton")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        var physicalContext = makeContext(hero: hero, companion: companion, enemyBuild: skeleton)
        var holyContext = makeContext(hero: hero, companion: companion, enemyBuild: skeleton)

        let physical = physicalContext.resolveDamage(
            .directAbilityHit(amount: 10, target: skeleton.combatant, keyword: .physical, sourceActorID: hero.id)
        )
        let holy = holyContext.resolveDamage(
            .directAbilityHit(amount: 10, target: skeleton.combatant, keyword: .holy, sourceActorID: hero.id)
        )

        let drPercent = skeleton.combatant.primaryStats.toughnessMitigationPercent
        let expectedPhysical = CombatRounding.scaled(10, multiplier: 1.0 - drPercent)
        let holyBefore = CombatRounding.scaled(10, multiplier: 1.3)
        let expectedHoly = CombatRounding.scaled(holyBefore, multiplier: 1.0 - drPercent)
        try #expect(physical.healthLost == expectedPhysical)
        try #expect(holy.healthLost == expectedHoly)
        try #expect(holy.healthLost > physical.healthLost)
    }

    @Test func frostwardenFreezeAuraSkipsOddRounds() throws {
        let frostwarden = try enemyBuild(id: "the_frostwarden")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: frostwarden)

        context.turnCount += 1
        _ = EffectTurnEngine.advanceAll(context: &context)
        let oddMeter = context.roster.activeEffects(for: hero).contains {
            if case .controlMeter(.freeze, _, _) = $0.effect {
                return true
            }
            return false
        }
        try #expect(!oddMeter)

        context.turnCount += 1
        _ = EffectTurnEngine.advanceAll(context: &context)
        let evenMeter = context.roster.activeEffects(for: hero).contains {
            if case .controlMeter(.freeze, _, _) = $0.effect {
                return true
            }
            return false
        }
        try #expect(evenMeter)
    }

    @Test func frostwardenFreezeDamageChargesControlMeterAndTriggersSkip() throws {
        let frostwarden = try enemyBuild(id: "the_frostwarden")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: frostwarden)
        let threshold = ControlMeterEngine.threshold(for: hero, in: context)
        try #expect(threshold > 0)

        var events: [ActionEvent] = []
        // Aura fires on even rounds only (`endTurn` increments `turnCount` first).
        for _ in 0 ..< (threshold * 2) {
            context.turnCount += 1
            events.append(contentsOf: EffectTurnEngine.advanceAll(context: &context))
        }

        let heroMeter = context.roster.activeEffects(for: hero).first {
            if case .controlMeter(.freeze, _, _) = $0.effect {
                return true
            }
            return false
        }
        try #require(heroMeter != nil)
        #expect(context.roster.hasPendingActionSkip(for: hero, keyword: .freeze))
        #expect(events.contains { $0.effectKind == .controlTriggered })
    }

    @Test func mimicDoubleDamageOnFirstAttack() throws {
        let mimic = try enemyBuild(id: "mimic")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 30)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 30)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: mimic)

        let first = context.resolveDamage(
            .directAbilityHit(amount: 2, target: hero, keyword: .physical, sourceActorID: mimic.combatant.id)
        )
        let second = context.resolveDamage(
            .directAbilityHit(amount: 2, target: hero, keyword: .physical, sourceActorID: mimic.combatant.id)
        )

        let strengthPercent = mimic.combatant.primaryStats.statDamageBonusPercent(keyword: .physical)
        let strengthBonus = CombatRounding.scaled(2, multiplier: strengthPercent)
        let baseDamage = 2 + strengthBonus
        try #expect(first.healthLost == baseDamage * 2)
        try #expect(second.healthLost == baseDamage)
    }

    @Test func damageTakenReductionReducesMatchingKeyword() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var reducedContext = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyModifiers: CombatModifierProfile(damageTakenReduction: [.bleed: 0.3])
        )
        var baselineContext = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy
        )

        let reduced = reducedContext.resolveDamage(
            DamageRequest(
                amount: 10,
                target: enemy,
                keyword: .bleed,
                sourceActorID: hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )
        let baseline = baselineContext.resolveDamage(
            DamageRequest(
                amount: 10,
                target: enemy,
                keyword: .bleed,
                sourceActorID: hero.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            )
        )

        try #expect(reduced.healthLost == CombatRounding.scaled(10, multiplier: 0.7))
        try #expect(baseline.healthLost == 10)
        try #expect(reduced.healthLost < baseline.healthLost)
    }

    @Test func forgeGolemRampsStunOrBurnEachEnemyTurn() throws {
        let golem = try enemyBuild(id: "the_forge_golem")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 99)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 99)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: golem)

        _ = BattleTestFixtures.endTurns(2, on: &context)

        let ramp = context.roster.enemy.keywordDamageRamp
        try #expect(ramp[.physical, default: 0] == 0)
        try #expect(ramp[.stun, default: 0] + ramp[.burn, default: 0] == 2)

        let stunBonus = DamagePipeline.outgoingDamageBonus(
            for: golem.combatant.id,
            keyword: .stun,
            in: context
        )
        let burnBonus = DamagePipeline.outgoingDamageBonus(
            for: golem.combatant.id,
            keyword: .burn,
            in: context
        )
        let physicalBonus = DamagePipeline.outgoingDamageBonus(
            for: golem.combatant.id,
            keyword: .physical,
            in: context
        )
        try #expect(stunBonus + burnBonus == 2)
        try #expect(physicalBonus == 0)
        try #expect(!golem.modifiers.triggers.damageIncreasesEveryOtherTurn)
    }

    @Test func ironBearRampsPhysicalOrStunEachEnemyTurn() throws {
        let bear = try enemyBuild(id: "the_iron_bear")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 99)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 99)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: bear)

        _ = BattleTestFixtures.endTurns(2, on: &context)

        let ramp = context.roster.enemy.keywordDamageRamp
        try #expect(ramp[.burn, default: 0] == 0)
        try #expect(ramp[.physical, default: 0] + ramp[.stun, default: 0] == 2)

        let physicalBonus = DamagePipeline.outgoingDamageBonus(
            for: bear.combatant.id,
            keyword: .physical,
            in: context
        )
        let stunBonus = DamagePipeline.outgoingDamageBonus(
            for: bear.combatant.id,
            keyword: .stun,
            in: context
        )
        let burnBonus = DamagePipeline.outgoingDamageBonus(
            for: bear.combatant.id,
            keyword: .burn,
            in: context
        )
        try #expect(physicalBonus + stunBonus == 2)
        try #expect(burnBonus == 0)
        try #expect(!bear.modifiers.triggers.damageIncreasesEveryOtherTurn)
    }

    @Test func blightTreantRampsPoisonOrBleedEachEnemyTurn() throws {
        let treant = try enemyBuild(id: "the_blight_treant")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 99)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 99)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: treant)

        _ = BattleTestFixtures.endTurns(2, on: &context)

        let ramp = context.roster.enemy.keywordDamageRamp
        try #expect(ramp[.physical, default: 0] == 0)
        try #expect(ramp[.poison, default: 0] + ramp[.bleed, default: 0] == 2)

        let poisonBonus = DamagePipeline.outgoingDamageBonus(
            for: treant.combatant.id,
            keyword: .poison,
            in: context
        )
        let bleedBonus = DamagePipeline.outgoingDamageBonus(
            for: treant.combatant.id,
            keyword: .bleed,
            in: context
        )
        let physicalBonus = DamagePipeline.outgoingDamageBonus(
            for: treant.combatant.id,
            keyword: .physical,
            in: context
        )
        try #expect(poisonBonus + bleedBonus == 2)
        try #expect(physicalBonus == 0)
        try #expect(!treant.modifiers.triggers.damageIncreasesEveryOtherTurn)
    }

    @Test func frostwardenRampsFreezeEveryOtherTurnOnly() throws {
        let frostwarden = try enemyBuild(id: "the_frostwarden")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 99)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 99)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: frostwarden)

        _ = BattleTestFixtures.endTurns(1, on: &context)
        try #expect(
            DamagePipeline.outgoingDamageBonus(
                for: frostwarden.combatant.id,
                keyword: .freeze,
                in: context
            ) == 0
        )

        _ = BattleTestFixtures.endTurns(1, on: &context)
        let freezeBonus = DamagePipeline.outgoingDamageBonus(
            for: frostwarden.combatant.id,
            keyword: .freeze,
            in: context
        )
        let burnBonus = DamagePipeline.outgoingDamageBonus(
            for: frostwarden.combatant.id,
            keyword: .burn,
            in: context
        )
        let physicalBonus = DamagePipeline.outgoingDamageBonus(
            for: frostwarden.combatant.id,
            keyword: .physical,
            in: context
        )
        try #expect(freezeBonus == 1)
        try #expect(burnBonus == 0)
        try #expect(physicalBonus == 0)
        try #expect(frostwarden.modifiers.triggers.damageIncreasesEveryOtherTurnKeyword == .freeze)
    }
}
