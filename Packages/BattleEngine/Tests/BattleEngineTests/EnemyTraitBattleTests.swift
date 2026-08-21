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
        enemyBuild: CombatBuild,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemyBuild.combatant,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
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

    @Test func randomBossDamageAurasRollOnceForBothPartyMembers() throws {
        try assertRandomBossDamageAura(
            enemyID: "the_forge_golem",
            firstKeyword: .stun,
            secondKeyword: .burn
        )
        try assertRandomBossDamageAura(
            enemyID: "the_blight_treant",
            firstKeyword: .poison,
            secondKeyword: .bleed
        )
        try assertRandomBossDamageAura(
            enemyID: "the_iron_bear",
            firstKeyword: .physical,
            secondKeyword: .stun
        )
    }

    private func assertRandomBossDamageAura(
        enemyID: String,
        firstKeyword: Keyword,
        secondKeyword: Keyword
    ) throws {
        let boss = try enemyBuild(id: enemyID)
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 99)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 99)
        var context = makeContext(
            hero: hero,
            companion: companion,
            enemyBuild: boss,
            heroModifiers: CombatModifierProfile(
                damageTakenVulnerability: [firstKeyword: 1.0]
            ),
            companionModifiers: CombatModifierProfile(
                damageTakenVulnerability: [secondKeyword: 1.0]
            )
        )

        context.appliesFightPacing = false
        for turn in 1 ... 8 {
            context.turnCount = turn
            let heroHealthBefore = context.roster.health(for: hero)
            let companionHealthBefore = context.roster.health(for: companion)
            _ = EffectTurnEngine.advanceAll(context: &context)

            let heroLoss = heroHealthBefore - context.roster.health(for: hero)
            let companionLoss = companionHealthBefore - context.roster.health(for: companion)
            try #expect(
                heroLoss + companionLoss == 3,
                "\(enemyID) turn \(turn): hero \(heroLoss), companion \(companionLoss)"
            )
            try #expect(Set([heroLoss, companionLoss]) == Set([1, 2]))
        }
    }

    @Test func frostwardenFreezeAuraDoesNotRampOutgoingFreezeDamage() throws {
        let frostwarden = try enemyBuild(id: "the_frostwarden")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 99)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 99)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: frostwarden)

        context.turnCount = 2
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
        try #expect(freezeBonus == 0)
        try #expect(burnBonus == 0)
        try #expect(physicalBonus == 0)
    }
}
