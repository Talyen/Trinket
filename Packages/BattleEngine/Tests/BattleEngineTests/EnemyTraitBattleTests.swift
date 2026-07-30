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
        BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemyBuild.combatant)
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
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

    @Test func goblinBurnVulnerability() throws {
        let goblin = try enemyBuild(id: "goblin")
        try #expect(goblin.modifiers.damageTakenVulnerability(for: .burn) == 0.30)
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

    @Test func livingArmorBlockPerTurnAndBleedReduction() throws {
        let livingArmor = try enemyBuild(id: "living_armor")
        try #expect(livingArmor.modifiers.triggers.blockPerTurn == 1)
        try #expect(livingArmor.modifiers.damageTakenReduction(for: .bleed) == 0.30)
    }

    @Test func necromancerLeechChanceAndHolyVulnerability() throws {
        let necromancer = try enemyBuild(id: "necromancer")
        try #expect(necromancer.modifiers.triggers.leechChancePercent == 0.20)
        try #expect(necromancer.modifiers.damageTakenVulnerability(for: .holy) == 0.30)
    }
}
