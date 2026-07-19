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
    ) -> BattleEngineContext {
        BattleEngineContext(
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

        let toughnessMitigation = skeleton.combatant.primaryStats.toughnessMitigation
        try #expect(physical.healthLost == 10 - toughnessMitigation)
        // Holy weakness (30%) applies before Toughness mitigation.
        let holyBeforeMitigation = Int((10.0 * 1.3).rounded(.up))
        try #expect(holy.healthLost == holyBeforeMitigation - toughnessMitigation)
        try #expect(holy.healthLost > physical.healthLost)
    }

    @Test func goblinNimbleDodgeAndScrawnyVulnerability() throws {
        let goblin = try enemyBuild(id: "goblin")
        try #expect(goblin.modifiers.dodgeChanceBonus > 0)
        try #expect(goblin.modifiers.damageTakenVulnerability(for: .physical) > 0)
    }

    @Test func mimicAmbushAddsFirstStrikeDamage() throws {
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

        let strengthBonus = mimic.combatant.primaryStats.statBonusForDamage(keyword: .physical)
        let ambushBonus = mimic.modifiers.ambushBonusDamage
        try #expect(ambushBonus > 0)
        try #expect(first.healthLost == 2 + strengthBonus + ambushBonus)
        try #expect(second.healthLost == 2 + strengthBonus)
    }

    @Test func livingArmorCannotBeHealed() throws {
        let livingArmor = try enemyBuild(id: "living_armor")
        try #expect(livingArmor.modifiers.cannotBeHealed)
    }

    @Test func hemorrhageWithGravePowerDoesNotDoubleImmediateBleed() throws {
        let necromancer = try enemyBuild(id: "necromancer")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 100)
        var context = makeContext(hero: hero, companion: companion, enemyBuild: necromancer)
        var enemyRuntime = try #require(context.roster.runtime(for: necromancer.combatant))
        enemyRuntime.actionCount = 5
        context.roster.update(enemyRuntime)

        let heroHealthBefore = context.roster.health(for: hero)
        let matchup = BattleMatchup(hero: hero, companion: companion, enemy: necromancer.combatant)
        let turnNumber = enemyRuntime.actionCount + 1
        let ability = try #require(
            BattleTurnEngine.selectedEnemyAbility(for: necromancer.combatant, turnNumber: turnNumber)
        )

        _ = BattleTurnEngine.performAbility(
            ability,
            actor: necromancer.combatant,
            matchup: matchup,
            context: &context
        )

        try #expect(context.roster.health(for: hero) == heroHealthBefore - 7)
    }
}
