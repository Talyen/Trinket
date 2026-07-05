import XCTest
@testable import BattleEngine
import TrinketCore
import TrinketContent

final class EnemyTraitBattleTests: XCTestCase {
    private func enemyBuild(id: String) throws -> CombatBuild {
        let enemy = try XCTUnwrap(GameContent.enemy(matching: id))
        return CombatBuildResolver.build(enemy: enemy)
    }

    private func makeContext(
        hero: Combatant,
        pet: Combatant,
        enemyBuild: CombatBuild
    ) -> BattleEngineContext {
        BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemyBuild.combatant)
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: enemyBuild.modifiers
        )
    }

    func testSkeletonTakesExtraHolyDamage() throws {
        let skeleton = try enemyBuild(id: "skeleton")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 20)
        var physicalContext = makeContext(hero: hero, pet: pet, enemyBuild: skeleton)
        var holyContext = makeContext(hero: hero, pet: pet, enemyBuild: skeleton)

        let physical = physicalContext.resolveDamage(
            .directAbilityHit(amount: 10, target: skeleton.combatant, keyword: .physical, sourceActorID: hero.id)
        )
        let holy = holyContext.resolveDamage(
            .directAbilityHit(amount: 10, target: skeleton.combatant, keyword: .holy, sourceActorID: hero.id)
        )

        XCTAssertEqual(physical.healthLost, 10)
        XCTAssertEqual(holy.healthLost, 13)
    }

    func testGoblinNimbleDodgeAndScrawnyVulnerability() throws {
        let goblin = try enemyBuild(id: "goblin")
        XCTAssertGreaterThan(goblin.modifiers.dodgeChanceBonus, 0)
        XCTAssertGreaterThan(goblin.modifiers.damageTakenVulnerability(for: .physical), 0)
    }

    func testMimicAmbushAddsFirstStrikeDamage() throws {
        let mimic = try enemyBuild(id: "mimic")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 30)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 30)
        var context = makeContext(hero: hero, pet: pet, enemyBuild: mimic)

        let first = context.resolveDamage(
            .directAbilityHit(amount: 2, target: hero, keyword: .physical, sourceActorID: mimic.combatant.id)
        )
        let second = context.resolveDamage(
            .directAbilityHit(amount: 2, target: hero, keyword: .physical, sourceActorID: mimic.combatant.id)
        )

        XCTAssertEqual(first.healthLost, 6)
        XCTAssertEqual(second.healthLost, 3)
    }

    func testLivingArmorCannotBeHealed() throws {
        let livingArmor = try enemyBuild(id: "living_armor")
        XCTAssertTrue(livingArmor.modifiers.cannotBeHealed)
    }

    func testHemorrhageWithGravePowerDoesNotDoubleImmediateBleed() throws {
        let necromancer = try enemyBuild(id: "necromancer")
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 100)
        var context = makeContext(hero: hero, pet: pet, enemyBuild: necromancer)
        var enemyRuntime = try XCTUnwrap(context.roster.runtime(for: necromancer.combatant))
        enemyRuntime.actionCount = 5
        context.roster.update(enemyRuntime)

        let heroHealthBefore = context.roster.health(for: hero)
        let matchup = BattleMatchup(hero: hero, pet: pet, enemy: necromancer.combatant)

        _ = BattleTurnEngine.performAction(
            actor: necromancer.combatant,
            abilityTarget: hero,
            matchup: matchup,
            context: &context
        )

        XCTAssertEqual(context.roster.health(for: hero), heroHealthBefore - 6)
    }
}
