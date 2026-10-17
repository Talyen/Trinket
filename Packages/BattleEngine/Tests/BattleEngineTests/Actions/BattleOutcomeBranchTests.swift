import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BattleOutcomeBranchTests {
    @Test func `luck potion resolves one seeded combat gain`() throws {
        var seenKeywords: Set<Keyword> = []
        for seed in UInt64(1) ... 192 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroAbilities: [.slash], companionAbilities: [.slash], enemyMaxHealth: 500,
                heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 },
                rngSeed: seed, dealOpeningHand: false, appliesFightPacing: false,
            )
            battle.roster.companion.currentHealth = 1
            let events = battle.performTestAction(.luckPotion)
            #expect(!events.contains { $0.kind == .abilityDamage })
            #expect(battle.hand.cards.count == 1)
            let gain = try #require(events.first { $0.effectKind != nil })
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

    @Test(arguments: [false, true])
    func `full Health luck potion excludes healing even with a defeated ally`(companionDefeated: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(rngSeed: 7, appliesFightPacing: false)
        if companionDefeated {
            battle.roster.companion.currentHealth = 0
        }
        let outcomes = BattleAbilityRules.possibleOutcomes(
            .luckPotion, action: BattleActionContext(actor: battle.hero, in: battle), in: battle,
        )
        #expect(!outcomes.branches.isEmpty)
        for branch in outcomes.branches {
            #expect(!branch.operations.contains { $0.keyword == .health })
            #expect(branch.operations.contains { $0.targetedEffect?.effect == .drawCards(1) })
        }
        let selected = BattleAbilityRules.resolveOutcome(.luckPotion, actor: battle.hero, in: &battle)
        #expect(!selected.targetedEffects.contains { $0.effect.keyword == .health })
        #expect(selected.targetedEffects.contains { $0.effect == .drawCards(1) })
    }

    @Test func `luck potion heals an injured ally over a full Health ally with lower maximum Health`() {
        var didHeal = false
        for seed in UInt64(1) ... 24 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroMaxHealth: 5, companionMaxHealth: 100, rngSeed: seed, dealOpeningHand: false, appliesFightPacing: false,
            )
            battle.roster.companion.currentHealth = 50
            let events = battle.performTestAction(.luckPotion)
            if let healed = events.first(where: { $0.effectKind == .instantHeal && $0.keyword == .health }) {
                #expect(healed.targetID == battle.companion.id)
                #expect(battle.health(of: battle.companion) > 50)
                didHeal = true
                break
            }
        }
        #expect(didHeal)
    }

    @Test func `seeded luck potion replay resolves the same combat outcome`() {
        var initial = BattleStateTestFactory.makeBattleWithAbilities(rngSeed: 7, dealOpeningHand: false, appliesFightPacing: false)
        initial.roster.companion.currentHealth = 1
        var first = initial
        var second = initial
        let firstEvents = first.performTestAction(.luckPotion)
        let secondEvents = second.performTestAction(.luckPotion)
        #expect(!firstEvents.isEmpty)
        #expect(firstEvents == secondEvents)
    }
}
