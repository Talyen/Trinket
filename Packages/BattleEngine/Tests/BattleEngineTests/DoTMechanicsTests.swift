import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct DoTMechanicsTests {
    private func isolatedBattle(
        heroAbilities: [Ability] = [],
        enemyEffects: [ActiveEffect] = [],
        heroEffects: [ActiveEffect] = [],
        heroActionIntervalTicks: Int = 4
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                actionIntervalTicks: heroActionIntervalTicks,
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

    @Test func burnFourDealsFourThenTwoThenOne() {
        var battle = isolatedBattle(heroAbilities: [burnAbility(potency: 4)])

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        let applyStep = battle.advanceOneStep()
        #expect(statusAmounts(from: applyStep.events == keyword: .burn), [4])
        #expect(burnPotency(on: battle) == 4)

        let tickOne = battle.advanceOneStep()
        #expect(statusAmounts(from: tickOne.events == keyword: .burn), [2])
        #expect(burnPotency(on: battle) == 2)

        let tickTwo = battle.advanceOneStep()
        #expect(statusAmounts(from: tickTwo.events == keyword: .burn), [1])
        #expect(burnPotency(on: battle) == 1)

        let tickThree = battle.advanceOneStep()
        #expect(statusAmounts(from: tickThree.events, keyword: .burn).isEmpty)
        #expect(burnPotency(on: battle == nil))
    }

    @Test func burnStacksMergeAndDecayTogether() {
        var battle = isolatedBattle(
            heroAbilities: [burnAbility(potency: 2)],
            enemyEffects: [ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)],
            heroActionIntervalTicks: 2
        )

        _ = battle.advanceOneStep()
        #expect(burnPotency(on: battle) == 2)

        _ = battle.advanceOneStep()
        #expect(burnPotency(on: battle) == 3)

        _ = battle.advanceOneStep()
        #expect(burnPotency(on: battle) == 1)
    }

    @Test func poisonEightDecaysToZero() {
        var battle = isolatedBattle(
            enemyEffects: [ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0)]
        )

        var amounts: [Int] = []
        for _ in 0 ..< 8 {
            let step = battle.advanceOneStep()
            amounts.append(contentsOf: statusAmounts(from: step.events, keyword: .poison))
            if battle.activeEffects(of: battle.enemy).contains(where: { $0.keyword == .poison }) == false {
                break
            }
        }

        #expect(amounts == [6, 5, 4, 3, 2, 1])
        #expect(battle.activeEffects(of: battle.enemy).filter { $0.keyword == .poison }.isEmpty)
    }

    @Test func poisonAppliesInitialDamage() {
        var battle = isolatedBattle(heroAbilities: [poisonAbility(potency: 8)])

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        let applyStep = battle.advanceOneStep()

        #expect(statusAmounts(from: applyStep.events == keyword: .poison), [8])
        #expect(
            battle.activeEffects(of: battle.enemy).first { $0.keyword == .poison }?.effect.potency == 8
        )
    }

    @Test func bleedFourInstancesDealSixteenTotal() {
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

        #expect(amounts == [4, 4, 4])
        #expect(battle.health(of: battle.enemy) == 84)
        #expect(battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }.isEmpty)
    }

    @Test func bleedInstancesTrackIndependently() {
        var battle = isolatedBattle(
            heroAbilities: [bleedAbility(potency: 6)],
            heroActionIntervalTicks: 2
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        #expect(battle.activeEffects(of: battle.enemy).filter { $0.keyword == .bleed }.count == 2)
    }

    @Test func burnRespectsBlockAndArmor() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                actionIntervalTicks: 2,
                abilities: [burnAbility(potency: 4)]
            ),
            pet: BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 20, 5), remainingTicks: 5),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 0.50, 5), remainingTicks: 5)
            ]
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        #expect(battle.health(of: battle.enemy) == 100)
    }

    @Test func cleanseRemovesMergedPoisonStack() {
        let cleanse = Ability(id: "cleanse", name: "Cleanse", tier: .basic, directDamage: 0, description: "Cleanse", effects: [.cleanse(.poison)])
        var battle = isolatedBattle(
            heroAbilities: [cleanse],
            heroEffects: [ActiveEffect(id: 1, effect: .poison(6), remainingTicks: 0)],
            heroActionIntervalTicks: 2
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        #expect(!(battle.activeEffects(of: battle.hero)).contains {
            if case .poison = $0.effect { return true }
            return false
        })
    }
}
