import XCTest
@testable import BattleEngine
import TrinketCore
import TrinketContent

final class BattleLoopEngineTests: XCTestCase {
    func testAdvanceOneStepMatchesBattleStateFacade() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])

        var direct = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)
        var facade = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        for _ in 0 ..< 8 {
            var context = direct.makeEngineContext()
            let step = BattleLoopEngine.advanceOneStep(
                matchup: direct.matchup,
                context: &context
            )
            direct.applyEngineContext(context)

            let facadeStep = facade.advanceOneStep()

            XCTAssertEqual(step, facadeStep)
            XCTAssertEqual(direct.events, facade.events)
            XCTAssertEqual(direct.actionCount, facade.actionCount)
            XCTAssertEqual(direct.health(of: direct.enemy), facade.health(of: facade.enemy))

            if direct.isBattleOver {
                break
            }
        }
    }
}
