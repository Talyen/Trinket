import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct DoTMechanicsTests {
    private func isolatedBattle(
        heroAbilities: [Ability] = [],
        enemyEffects: [ActiveEffect] = [],
        heroEffects: [ActiveEffect] = []
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                abilities: heroAbilities
            ),
            pet: BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100),
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
        from events: [ActionEvent],
        keyword: Keyword
    ) -> [Int] {
        events
            .filter { $0.kind == .status && $0.keyword == keyword }
            .map(\.amount)
    }

    private func burnPotency(on battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first { $0.effect.isDecayingDoT && $0.keyword == .burn }?.effect.potency
    }

    @Test func burnFourDealsFourThenTwoThenOne() throws {
        var battle = isolatedBattle(heroAbilities: [burnAbility(potency: 4)])

        let applyEvents = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))
        try #expect(statusAmounts(from: applyEvents, keyword: .burn) == [4])
        try #expect(burnPotency(on: battle) == 4)

        let tickOne = BattleTestFixtures.endTurn(on: &battle)
        try #expect(statusAmounts(from: tickOne, keyword: .burn) == [2])
        try #expect(burnPotency(on: battle) == 2)

        let tickTwo = BattleTestFixtures.endTurn(on: &battle)
        try #expect(statusAmounts(from: tickTwo, keyword: .burn) == [1])
        try #expect(burnPotency(on: battle) == 1)

        let tickThree = BattleTestFixtures.endTurn(on: &battle)
        try #expect(statusAmounts(from: tickThree, keyword: .burn).isEmpty)
        try #expect(burnPotency(on: battle) == nil)
    }

    @Test func burnStacksMergeAndDecayTogether() throws {
        var battle = isolatedBattle(
            heroAbilities: [burnAbility(potency: 2)],
            enemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)]
        )

        // End of round: burn 4 → 2.
        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(burnPotency(on: battle) == 2)

        // Play merges +2 onto the remaining stack → 4.
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        try #expect(burnPotency(on: battle) == 4)

        // Next end of round: burn 4 → 2.
        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(burnPotency(on: battle) == 2)
    }

    @Test func poisonEightDecaysToZero() throws {
        var battle = isolatedBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0)]
        )

        var amounts: [Int] = []
        for _ in 0 ..< 8 {
            let events = BattleTestFixtures.endTurn(on: &battle)
            amounts.append(contentsOf: statusAmounts(from: events, keyword: .poison))
            if battle.activeEffects(of: battle.enemy).contains(where: { $0.keyword == .poison }) == false {
                break
            }
        }

        try #expect(amounts == [6, 5, 4, 3, 2, 1])
        try #expect(battle.activeEffects(of: battle.enemy).filter { $0.keyword == .poison }.isEmpty)
    }

    @Test func poisonAppliesInitialDamage() throws {
        var battle = isolatedBattle(heroAbilities: [poisonAbility(potency: 8)])

        let applyEvents = try #require(try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle))

        try #expect(statusAmounts(from: applyEvents, keyword: .poison) == [8])
        try #expect(
            battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }?.effect.potency == 8
        )
    }

    @Test func bleedFourInstancesDealSixteenTotal() throws {
        var battle = isolatedBattle(heroAbilities: [bleedAbility(potency: 4)])

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        var amounts: [Int] = []
        for _ in 0 ..< 3 {
            let events = BattleTestFixtures.endTurn(on: &battle)
            amounts.append(contentsOf: statusAmounts(from: events, keyword: .bleed))
        }

        try #expect(amounts == [4, 4, 4])
        try #expect(battle.health(of: battle.enemy) == 84)
        try #expect(battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }.isEmpty)
    }

    @Test func bleedInstancesTrackIndependently() throws {
        var battle = isolatedBattle(heroAbilities: [bleedAbility(potency: 6)])

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        // Recycle: played card goes to bottom; opening hand had 2 copies from single-ability deck.
        if let second = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle) {
            _ = second
        } else {
            _ = BattleTestFixtures.endTurn(on: &battle)
            _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        }

        try #expect(battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }.count == 2)
    }

    @Test func burnRespectsBlockAndArmor() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                abilities: [burnAbility(potency: 4)]
            ),
            pet: BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 5),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 3), remainingTicks: 5)
            ]
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)
        _ = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: battle.enemy) == 100)
    }

    @Test func cleanseRemovesMergedPoisonStack() throws {
        let cleanse = Ability(id: "cleanse", name: "Cleanse", tier: .basic, directDamage: 0, description: "Cleanse", effects: [.cleanse(.poison)])
        var battle = isolatedBattle(
            heroAbilities: [cleanse],
            heroEffects: [ActiveEffect(id: 1, effect: .poison(6), remainingTicks: 0)]
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(!(battle.activeEffects(of: battle.hero)).contains {
            if case .poison = $0.effect { return true }
            return false
        })
    }
}
