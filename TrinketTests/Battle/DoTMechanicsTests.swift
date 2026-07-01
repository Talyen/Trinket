import XCTest
@testable import Trinket

final class DoTMechanicsTests: XCTestCase {
    private func passiveCombatant(
        id: String,
        name: String,
        role: Combatant.Role,
        maxHealth: Int = 100,
        actionIntervalTicks: Int = 100
    ) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: []
        )
    }

    private func isolatedBattle(
        heroAbilities: [Ability] = [],
        enemyEffects: [ActiveEffect] = [],
        heroEffects: [ActiveEffect] = [],
        heroActionIntervalTicks: Int = 4
    ) -> BattleState {
        BattleState(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                actionIntervalTicks: heroActionIntervalTicks,
                abilities: heroAbilities
            ),
            pet: passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: passiveCombatant(id: "enemy", name: "Enemy", role: .enemy),
            activeEnemyEffects: enemyEffects,
            activeHeroEffects: heroEffects
        )
    }

    private func burnAbility(potency: Int) -> Ability {
        Ability(id: "burn-\(potency)", name: "Burn", tier: .basic, directDamage: 0, description: "Burn", effects: [.burn(potency)])
    }

    private func poisonAbility(potency: Int) -> Ability {
        Ability(id: "poison-\(potency)", name: "Poison", tier: .basic, directDamage: 0, description: "Poison", effects: [.poison(potency)])
    }

    private func bleedAbility(potency: Int) -> Ability {
        Ability(id: "bleed-\(potency)", name: "Bleed", tier: .basic, directDamage: 0, description: "Bleed", effects: [.bleed(potency)])
    }

    private func statusAmounts(
        from events: [BattleState.ActionEvent],
        keyword: Keyword
    ) -> [Int] {
        events
            .filter { $0.kind == .status && $0.keyword == keyword }
            .map(\.amount)
    }

    private func burnPotency(on battle: BattleState) -> Int? {
        battle.activeEnemyEffects.first { $0.effect.isDecayingDoT && $0.keyword == .burn }?.effect.potency
    }

    func testBurnFourDealsFourThenTwoThenOne() {
        var battle = isolatedBattle(heroAbilities: [burnAbility(potency: 4)])

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        let applyStep = battle.advanceOneStep()
        XCTAssertEqual(statusAmounts(from: applyStep.events, keyword: .burn), [4])
        XCTAssertEqual(burnPotency(on: battle), 4)

        let tickOne = battle.advanceOneStep()
        XCTAssertEqual(statusAmounts(from: tickOne.events, keyword: .burn), [2])
        XCTAssertEqual(burnPotency(on: battle), 2)

        let tickTwo = battle.advanceOneStep()
        XCTAssertEqual(statusAmounts(from: tickTwo.events, keyword: .burn), [1])
        XCTAssertEqual(burnPotency(on: battle), 1)

        let tickThree = battle.advanceOneStep()
        XCTAssertTrue(statusAmounts(from: tickThree.events, keyword: .burn).isEmpty)
        XCTAssertNil(burnPotency(on: battle))
    }

    func testBurnStacksMergeAndDecayTogether() {
        var battle = isolatedBattle(
            heroAbilities: [burnAbility(potency: 2)],
            enemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)],
            heroActionIntervalTicks: 2
        )

        _ = battle.advanceOneStep()
        XCTAssertEqual(burnPotency(on: battle), 2)

        _ = battle.advanceOneStep()
        XCTAssertEqual(burnPotency(on: battle), 3)

        _ = battle.advanceOneStep()
        XCTAssertEqual(burnPotency(on: battle), 1)
    }

    func testPoisonEightDecaysToZero() {
        var battle = isolatedBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0)]
        )

        var amounts: [Int] = []
        for _ in 0 ..< 8 {
            let step = battle.advanceOneStep()
            amounts.append(contentsOf: statusAmounts(from: step.events, keyword: .poison))
            if battle.activeEnemyEffects.contains(where: { $0.keyword == .poison }) == false {
                break
            }
        }

        XCTAssertEqual(amounts, [6, 5, 4, 3, 2, 1])
        XCTAssertTrue(battle.activeEnemyEffects.filter { $0.keyword == .poison }.isEmpty)
    }

    func testPoisonAppliesInitialDamage() {
        var battle = isolatedBattle(heroAbilities: [poisonAbility(potency: 8)])

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        let applyStep = battle.advanceOneStep()

        XCTAssertEqual(statusAmounts(from: applyStep.events, keyword: .poison), [8])
        XCTAssertEqual(
            battle.activeEnemyEffects.first { $0.keyword == .poison }?.effect.potency,
            8
        )
    }

    func testBleedFourInstancesDealSixteenTotal() {
        var battle = isolatedBattle(heroAbilities: [bleedAbility(potency: 4)])

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        var amounts: [Int] = []
        for _ in 0 ..< 3 {
            let step = battle.advanceOneStep()
            amounts.append(contentsOf: statusAmounts(from: step.events, keyword: .bleed))
        }

        XCTAssertEqual(amounts, [4, 4, 4])
        XCTAssertEqual(battle.enemyHealth, 84)
        XCTAssertTrue(battle.activeEnemyEffects.filter { $0.keyword == .bleed }.isEmpty)
    }

    func testBleedInstancesTrackIndependently() {
        var battle = isolatedBattle(
            heroAbilities: [bleedAbility(potency: 6)],
            heroActionIntervalTicks: 2
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertEqual(battle.activeEnemyEffects.filter { $0.keyword == .bleed }.count, 2)
    }

    func testBurnRespectsBlockAndArmor() {
        var battle = BattleState(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                actionIntervalTicks: 2,
                abilities: [burnAbility(potency: 4)]
            ),
            pet: passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: passiveCombatant(id: "enemy", name: "Enemy", role: .enemy),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 20, 5), remainingTicks: 5),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 0.50, 5), remainingTicks: 5)
            ]
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertEqual(battle.enemyHealth, 100)
    }

    func testCleanseRemovesMergedPoisonStack() {
        let cleanse = Ability(id: "cleanse", name: "Cleanse", tier: .basic, directDamage: 0, description: "Cleanse", effects: [.cleanse(.poison, 3)])
        var battle = isolatedBattle(
            heroAbilities: [cleanse],
            heroEffects: [ActiveEffect(id: 1, effect: .poison(6), remainingTicks: 0)],
            heroActionIntervalTicks: 2
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertFalse(battle.activeHeroEffects.contains {
            if case .poison = $0.effect { return true }
            return false
        })
    }

    func testSavedActiveEffectRoundTripsBleedTicks() throws {
        let original = ActiveEffect(id: 7, effect: .bleed(5), remainingTicks: 2)
        let restored = try XCTUnwrap(SavedActiveEffect(original).activeEffect())

        XCTAssertEqual(restored, original)
    }
}
