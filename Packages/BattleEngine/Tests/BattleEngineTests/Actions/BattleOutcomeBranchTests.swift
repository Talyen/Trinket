import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BattleOutcomeBranchTests {
    @Test(arguments: [Keyword.bleed, .poison])
    func `caustic jab resolves one damage type without halving Block`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 500, heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        battle.rng = try BattleTestFixtures.rngSelectingOutcome(.causticJab, in: battle) {
            $0.damageComponents.contains { $0.keyword == keyword }
        }
        let events = battle.performTestAction(.causticJab)
        let hits = events.filter { $0.kind == .abilityDamage }
        #expect(hits.count == 1)
        #expect(hits.first?.keyword == keyword)
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 9)
        #expect(!events.contains { $0.effectKind == .shieldHalved })
    }

    @Test func `ordinary abilities preserve their definition and random state`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(rngSeed: 7, appliesFightPacing: false)
        let initialRNG = battle.rng
        let selected = BattleAbilityRules.resolveOutcome(.slash, actor: battle.hero, in: &battle)
        #expect(selected == .slash)
        #expect(battle.rng == initialRNG)
    }

    @Test(arguments: [Keyword.block, .thorns, .health])
    func `luck potion resolves one seeded combat gain`(keyword: Keyword) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], companionAbilities: [.slash], enemyMaxHealth: 500,
            heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.rng = try BattleTestFixtures.rngSelectingOutcome(.luckPotion, in: battle) {
            $0.targetedEffects.contains { $0.effect.keyword == keyword }
        }
        let events = battle.performTestAction(.luckPotion)
        #expect(!events.contains { $0.kind == .abilityDamage })
        #expect(battle.hand.cards.count == 1)
        let gain = try #require(events.first { $0.effectKind != nil })
        #expect(gain.keyword == keyword)
        #expect((1 ... 12).contains(gain.amount))
        switch keyword {
        case .thorns:
            #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .thorns(gain.amount) })
        case .block:
            #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == gain.amount)
        case .health:
            #expect(battle.roster.companion.currentHealth == 1 + gain.amount)
            #expect(battle.roster.hero.currentHealth == battle.roster.hero.maxHealth)
        default:
            Issue.record("Unexpected Luck Potion branch")
        }
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

    @Test func `luck potion heals an injured ally over a full Health ally with lower maximum Health`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 5, companionMaxHealth: 100, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 50
        battle.rng = try BattleTestFixtures.rngSelectingOutcome(.luckPotion, in: battle) {
            $0.targetedEffects.contains { $0.effect.keyword == .health }
        }
        let events = battle.performTestAction(.luckPotion)
        let healed = try #require(events.first { $0.effectKind == .instantHeal && $0.keyword == .health })
        #expect(healed.targetID == battle.companion.id)
        #expect(battle.health(of: battle.companion) > 50)
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

    @Test func `defeated ally target resolves partner when both are alive and picks dead combatant when one is defeated`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(rngSeed: 1, appliesFightPacing: false)
        let heroAction = BattleActionContext(actor: battle.hero, in: battle)
        let companionAction = BattleActionContext(actor: battle.companion, in: battle)

        // When both are alive, defeated ally falls back to the partner ally, not self
        #expect(heroAction.target(.defeatedAlly, in: battle).id == battle.companion.id)
        #expect(companionAction.target(.defeatedAlly, in: battle).id == battle.hero.id)

        // When companion is defeated
        battle.roster.companion.currentHealth = 0
        #expect(heroAction.target(.defeatedAlly, in: battle).id == battle.companion.id)
        #expect(companionAction.target(.defeatedAlly, in: battle).id == battle.companion.id)

        // When hero is defeated
        battle.roster.companion.currentHealth = battle.roster.companion.maxHealth
        battle.roster.hero.currentHealth = 0
        #expect(heroAction.target(.defeatedAlly, in: battle).id == battle.hero.id)
        #expect(companionAction.target(.defeatedAlly, in: battle).id == battle.hero.id)
    }
}
