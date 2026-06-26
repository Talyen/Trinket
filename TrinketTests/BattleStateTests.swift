import XCTest
@testable import Trinket

final class BattleStateTests: XCTestCase {
    func testStrikeDealsOnePhysicalDamage() {
        let strike = Ability.strike

        XCTAssertEqual(strike.name, "Strike")
        XCTAssertEqual(strike.damage, 1)
        XCTAssertEqual(strike.damageType, .physical)
        XCTAssertEqual(strike.summary, "1 Physical damage")
    }

    func testHeroAndPetActionsReduceEnemyHealth() {
        var battle = BattleState(hero: Combatant.heroes[0], pet: Combatant.pets[0])

        let heroAction = battle.performNextAction()
        XCTAssertEqual(battle.enemyHealth, 5)
        XCTAssertEqual(heroAction?.actorName, "Paladin")
        XCTAssertEqual(heroAction?.abilityName, "Strike")
        XCTAssertEqual(heroAction?.targetID, "training-slime")
        XCTAssertEqual(heroAction?.targetName, "Training Slime")
        XCTAssertEqual(heroAction?.amount, 1)
        XCTAssertEqual(heroAction?.damageType, .physical)
        XCTAssertEqual(heroAction?.floatingText, "Paladin Strike -1")
        XCTAssertEqual(battle.log.last?.text, "Paladin uses Strike for 1 Physical damage.")

        let petAction = battle.performNextAction()
        XCTAssertEqual(battle.enemyHealth, 4)
        XCTAssertEqual(petAction?.actorName, "Wolf")
        XCTAssertEqual(petAction?.abilityName, "Strike")
        XCTAssertEqual(petAction?.targetID, "training-slime")
        XCTAssertEqual(petAction?.targetName, "Training Slime")
        XCTAssertEqual(petAction?.amount, 1)
        XCTAssertEqual(petAction?.damageType, .physical)
        XCTAssertEqual(petAction?.floatingText, "Wolf Strike -1")
        XCTAssertEqual(battle.log.last?.text, "Wolf uses Strike for 1 Physical damage.")
    }

    func testTrainingSlimeIsDefeatedAfterSixActions() {
        var battle = BattleState(hero: Combatant.heroes[0], pet: Combatant.pets[0])

        for _ in 0..<6 {
            battle.performNextAction()
        }

        XCTAssertTrue(battle.isEnemyDefeated)
        XCTAssertEqual(battle.enemyHealth, 0)
        XCTAssertEqual(battle.actionCount, 6)
        XCTAssertEqual(battle.log.last?.text, "Training Slime is defeated.")

        let defeatedAction = battle.performNextAction()
        XCTAssertNil(defeatedAction)
        XCTAssertEqual(battle.actionCount, 6)
        XCTAssertEqual(battle.enemyHealth, 0)
    }
}
