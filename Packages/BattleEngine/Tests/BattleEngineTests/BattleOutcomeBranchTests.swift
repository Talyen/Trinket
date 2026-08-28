import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleOutcomeBranchTests {
    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyMaxHealth: Int = 500,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: enemyMaxHealth,
            rngSeed: rngSeed
        )
    }

    private func playBranchableCard(
        heroAbilities: [Ability],
        companionAbilities: [Ability],
        abilityNamed name: String,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) throws -> (battle: BattleState, events: [ActionEvent]) {
        var battle = makeBattle(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: 500,
            rngSeed: rngSeed
        )
        let card = try #require(battle.hand.cards.first { $0.ability.name == name })
        let events = try battle.playCard(cardID: card.id)
        return (battle, events)
    }

    @Test func seededDeterminismResolvesSameBranch() throws {
        func signature(_ events: [ActionEvent]) -> [String] {
            events.map { "\($0.kind)|\(String(describing: $0.effectKind))|\($0.amount)|\($0.abilityID)" }
        }
        let first = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            rngSeed: 7
        )
        let second = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            rngSeed: 7
        )
        #expect(signature(first.events) == signature(second.events))
    }

    @Test func outcomeBranchesResolveValidBranchEffects() throws {
        let result = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            rngSeed: 42
        )
        let enemyEffects = result.battle.activeEffects(of: result.battle.enemy)
        let appliedBleed = enemyEffects.contains { effect in
            guard case .bleed = effect.effect else { return false }
            return true
        }
        let appliedStun = result.events.contains { event in
            event.keyword == .stun
        }
        #expect(appliedBleed || appliedStun)
    }

    @Test func resourceGainBranchResolvesCorrectly() throws {
        let result = try playBranchableCard(
            heroAbilities: [.tithe, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Tithe",
            rngSeed: 42
        )
        let gainedGold = result.battle.gold > 0
        let dealtHoly = result.events.contains { $0.keyword == .holy }
        #expect(gainedGold || dealtHoly)
    }
}
