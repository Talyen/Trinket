import Testing
import TrinketContent

@Suite("Enemy catalog loadout invariants")
struct EnemyCatalogParameterizedTests {
    @Test(arguments: GameContent.enemies)
    func eachEnemyHasBasicSkillUltimate(enemy: Enemy) {
        let loadout = enemy.combatant.abilityLoadout
        #require(loadout.basic != nil, "\(enemy.name) should have a basic ability")
        #require(loadout.skill != nil, "\(enemy.name) should have a skill ability")
        #require(loadout.ultimate != nil, "\(enemy.name) should have an ultimate ability")
    }
}
