import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BattleOutcomeBranchTests {
    @Test func `luck potion resolves one seeded combat gain`() throws {
        var seenKeywords: Set<Keyword> = []
        for seed in UInt64(1) ... 192 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                enemyMaxHealth: 500,
                heroModifiers: .init(triggers: CombatTraitTriggers(damage: DamageTriggers(criticalChanceBonus: -1))),
                rngSeed: seed, dealOpeningHand: false,
            )
            battle.appliesFightPacing = false
            battle.roster.companion.currentHealth = 1
            let events = BattleTurnEngine.performAction(
                ability: .luckPotion, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
            #expect(!events.contains { $0.kind == .abilityDamage })
            let gain = try #require(events.first { $0.kind == .effect })
            #expect((1 ... 12).contains(gain.amount))
            seenKeywords.insert(gain.keyword)
            switch gain.keyword {
            case .thorns:
                #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .thorns(gain.amount) })
            case .block:
                #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == gain.amount)
            case .health:
                #expect(battle.roster.companion.currentHealth == 1 + gain.amount)
                #expect(battle.roster.hero.currentHealth == battle.roster.hero.maxHealth)
            default:
                Issue.record("Luck Potion produced unsupported keyword \(gain.keyword)")
            }
            if seenKeywords == [.block, .thorns, .health] {
                break
            }
        }
        #expect(seenKeywords == [.block, .thorns, .health])
    }

    @Test func `seeded luck potion replay resolves the same combat outcome`() {
        var initial = BattleStateTestFactory.makeBattleWithAbilities(rngSeed: 7, dealOpeningHand: false)
        initial.appliesFightPacing = false
        initial.roster.companion.currentHealth = 1
        var first = initial
        var second = initial
        let firstEvents = BattleTurnEngine.performAction(
            ability: .luckPotion, actor: first.hero, abilityTarget: first.enemy, context: &first,
        )
        let secondEvents = BattleTurnEngine.performAction(
            ability: .luckPotion, actor: second.hero, abilityTarget: second.enemy, context: &second,
        )
        #expect(!firstEvents.isEmpty)
        #expect(firstEvents == secondEvents)
    }
}
