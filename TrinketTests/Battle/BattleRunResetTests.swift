import BattleEngine
import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

final class BattleRunResetTests: XCTestCase {
    @MainActor
    func testResetPreservesEnemyModifiers() throws {
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))
        let configuration = ActiveBattleConfiguration.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )
        let run = BattleRun(configuration: configuration)

        run.reset(from: configuration)

        XCTAssertGreaterThan(run.state.modifiers(for: enemy.combatant.id).controlResistancePercent, 0)
    }
}
