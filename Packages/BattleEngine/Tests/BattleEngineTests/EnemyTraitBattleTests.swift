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

        try #expect(physical.healthLost == 10)
        try #expect(holy.healthLost == 13)
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

        try #expect(first.healthLost == 5)
        try #expect(second.healthLost == 3)
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
