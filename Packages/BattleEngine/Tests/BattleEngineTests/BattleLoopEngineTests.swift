import Testing
@testable import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleLoopEngineTests {
    @Test func advanceOneStepMatchesBattleStateFacade() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])

        var direct = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)
        var facade = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        for _ in 0 ..< 8 {
            let step = BattleLoopEngine.advanceOneStep(
                matchup: direct.matchup,
                context: &direct
            )

            let facadeStep = facade.advanceOneStep()

            try #expect(step == facadeStep)
            try #expect(direct.events == facade.events)
            try #expect(direct.actionCount == facade.actionCount)
            try #expect(direct.health(of: direct.enemy) == facade.health(of: facade.enemy))

            if direct.isBattleOver {
                break
            }
        }
    }
}
