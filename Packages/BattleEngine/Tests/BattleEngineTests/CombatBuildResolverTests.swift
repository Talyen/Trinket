import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CombatBuildResolverTests {
    @Test(arguments: [41, 60, 100, 250, 1000], [false, true])
    func `enemy build keeps growing past forty`(level: Int, isBoss: Bool) throws {
        let enemy = try #require(GameContent.enemies.first { $0.isBoss == isBoss })
        let previous = CombatBuildResolver.build(enemy: enemy, level: level - 1)
        let current = CombatBuildResolver.build(enemy: enemy, level: level)
        let atForty = CombatBuildResolver.build(enemy: enemy, level: 40)
        #expect(current.combatant.maxHealth >= previous.combatant.maxHealth)
        #expect(current.combatant.maxHealth > atForty.combatant.maxHealth)
        #expect(current.modifiers.outgoingDamagePercent > previous.modifiers.outgoingDamagePercent)
        #expect(current.combatant.abilityChoices == enemy.combatant.abilityChoices)
    }
}
