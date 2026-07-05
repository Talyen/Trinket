import BattleEngine
import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class BattleRunResetTests: XCTestCase {
    func testResetPreservesEnemyModifiers() throws {
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )
        let session = BattleSession()
        session.activeBattle = configuration

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )

        XCTAssertGreaterThan(
            session.state?.modifiers(for: enemy.combatant.id).controlResistancePercent ?? 0,
            0
        )
    }
}
