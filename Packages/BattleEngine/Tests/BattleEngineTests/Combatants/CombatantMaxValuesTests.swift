import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct CombatantMaxValuesTests {
    @Test(arguments: [(Int.min, 0, 0), (7, 7, 7), (Int.max, 20, 10)])
    func `resource losses never create resources or exceed the current balance`(requested: Int, damage: Int, spent: Int) {
        var runtime = CombatantRuntime(combatant: CombatantFixtures.passiveEnemy(maxHealth: 20, maxMana: 10))

        #expect(runtime.takeRawDamage(requested) == damage)
        #expect(runtime.spendMana(requested) == spent)
        #expect(runtime.currentHealth == 20 - damage)
        #expect(runtime.currentMana == 10 - spent)
        #expect(runtime.defeatProgress.remainingHealth == 20 - damage)
    }

    @Test(arguments: [Int.min, Int.max])
    func `starting resources are bounded before defeat and resource checks`(requested: Int) {
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 20, maxMana: 10)
        let battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: enemy,
            enemyEffects: [ActiveEffect(id: 1, effect: .maximumManaBonus(3), remainingTurns: 0)],
            enemyHealth: requested, enemyMana: requested,
            enemyModifiers: .init(maximumHealthBonus: 2, maximumManaBonus: 3),
        )
        let runtime = battle.roster.enemy
        let defeated = requested < 0
        #expect(runtime.currentHealth == (defeated ? 0 : 22))
        #expect(runtime.currentMana == (defeated ? 0 : 16))
        #expect(battle.isEnemyDefeated == defeated)
        #expect(runtime.defeatProgress.remainingHealth == (defeated ? 0 : 22))
    }

    @Test func `maximum stats saturate overflowing flat bonuses`() {
        let hero = CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 20)
        let stacks = [
            ActiveEffect(id: 1, effect: .maximumManaBonus(Int.max), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .maximumManaBonus(1), remainingTurns: 0),
        ]
        #expect(CombatantRuntime(combatant: hero, initialActiveEffects: stacks).maxMana == Int.max)
        #expect(EffectSummaryBuilder.build(for: stacks).first?.text.contains(String(Int.max)) == true)
    }

    @Test(arguments: [
        (20, 4, 0.5, 36, 39, 36),
        (20, 4, -0.5, 12, 15, 12),
        (20, 4, -2.0, 0, 3, 0),
        (0, 4, 0.5, 0, 0, 36),
        (2, Int.max, 1.0, Int.max, Int.max, Int.max),
        (20, 4, Double.greatestFiniteMagnitude, Int.max, Int.max, Int.max),
    ])
    func `all battle roles start with build stats and add active Mana capacity`(
        baseMana: Int, flatBonus: Int, percentBonus: Double, startingMana: Int, capacity: Int, health: Int,
    ) {
        let modifiers = CombatModifierProfile(
            maximumHealthPercentBonus: percentBonus, maximumHealthBonus: flatBonus,
            maximumManaBonus: flatBonus, maximumManaPercentBonus: percentBonus,
        )
        let effects = [ActiveEffect(id: 1, effect: .maximumManaBonus(3), remainingTurns: 2)]
        let state = BattleState(
            hero: CombatantFixtures.passiveHero(maxMana: baseMana),
            companion: CombatantFixtures.passiveCompanion(maxMana: baseMana),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20, maxMana: baseMana),
            activeEnemyEffects: effects,
            activeHeroEffects: effects,
            activeCompanionEffects: effects,
            heroModifiers: modifiers,
            companionModifiers: modifiers,
            enemyModifiers: modifiers,
            dealOpeningHand: false,
        )

        for participant in BattleParticipant.allCases {
            let runtime = state.roster[participant]
            #expect(runtime.currentHealth == health)
            #expect(runtime.maxHealth == health)
            #expect(runtime.currentMana == startingMana)
            #expect(runtime.maxMana == capacity)
        }
    }
}
