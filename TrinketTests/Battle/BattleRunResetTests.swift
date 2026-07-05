import BattleEngine
import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

final class BattleRunResetTests: XCTestCase {
    @MainActor
    func testResetPreservesEnemyModifiers() throws {
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))
        let enemyBuild = CombatBuildResolver.build(enemy: enemy)
        let configuration = ActiveBattleConfiguration(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemyBuild.combatant,
            enemyModifiers: enemyBuild.modifiers
        )
        let run = BattleRun(configuration: configuration)

        run.reset(from: configuration)

        XCTAssertGreaterThan(run.state.modifiers(for: enemyBuild.combatant.id).controlResistancePercent, 0)
    }
}
