import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleOutcomeBranchTests {
    @Test func `luck potion skips unneeded restoration and targets lowest eligible ally`() {
        var outcomes: Set<Keyword> = []
        for seed in UInt64(1) ... 64 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroMaxHealth: 30, companionMaxHealth: 20,
                heroMaxMana: 10, heroMana: 6, companionMaxMana: 10, companionMana: 2,
                rngSeed: seed, dealOpeningHand: false,
            )
            battle.appliesFightPacing = false
            battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 12 }
            battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 5 }
            let events = BattleTurnEngine.performAction(
                ability: .luckPotion, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
            )
            if battle.mana(of: battle.companion) > 2 {
                outcomes.insert(.mana)
                #expect(battle.mana(of: battle.companion) == 9)
                #expect(battle.mana(of: battle.hero) == 6)
            } else if battle.health(of: battle.companion) > 5 {
                outcomes.insert(.health)
                #expect([12, 19].contains(battle.health(of: battle.companion)))
                #expect(battle.health(of: battle.hero) == 12)
            } else {
                outcomes.insert(.block)
                #expect(events.contains { $0.effectKind == .shieldApplied && $0.amount == 7 })
            }
        }
        #expect(outcomes == [.mana, .health, .block])
    }

    @Test(arguments: [0, 10])
    func `luck potion always gives block when party resources are full`(maxMana: Int) {
        for seed in UInt64(1) ... 32 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroMaxMana: maxMana, companionMaxMana: maxMana,
                rngSeed: seed, dealOpeningHand: false,
            )
            let events = BattleTurnEngine.performAction(
                ability: .luckPotion, actor: battle.companion, abilityTarget: battle.enemy, context: &battle,
            )
            #expect(events.contains { $0.effectKind == .shieldApplied && $0.amount == 7 })
            #expect(BattleTestFixtures.shieldPoints(for: battle.companion, in: battle) == 7)
        }
    }

    @Test func `luck potion ignores full or defeated low health allies`() {
        for heroHealth in [0, 5] {
            var sawHeal = false
            for seed in UInt64(1) ... 32 {
                var battle = BattleStateTestFactory.makeBattleWithAbilities(
                    heroMaxHealth: 5, companionMaxHealth: 30, rngSeed: seed, dealOpeningHand: false,
                )
                battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = heroHealth }
                battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 10 }
                _ = BattleTurnEngine.performAction(
                    ability: .luckPotion, actor: battle.companion, abilityTarget: battle.enemy, context: &battle,
                )
                #expect(battle.health(of: battle.hero) == heroHealth)
                if battle.health(of: battle.companion) > 10 {
                    sawHeal = true
                }
            }
            #expect(sawHeal)
        }
    }

    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability] = [],
        enemyMaxHealth: Int = 500,
        rngSeed: UInt64 = CombatantFixtures.deterministicBattleSeed,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: enemyMaxHealth,
            rngSeed: rngSeed,
        )
    }

    private func playBranchableCard(
        heroAbilities: [Ability],
        companionAbilities: [Ability],
        abilityNamed name: String,
        rngSeed: UInt64 = CombatantFixtures.deterministicBattleSeed,
    ) throws -> (battle: BattleState, events: [ActionEvent]) {
        var battle = makeBattle(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: 500,
            rngSeed: rngSeed,
        )
        let card = try #require(battle.hand.cards.first { $0.ability.name == name })
        let events = try battle.playCard(cardID: card.id)
        return (battle, events)
    }

    @Test func `seeded determinism resolves same branch`() throws {
        func signature(_ events: [ActionEvent]) -> [String] {
            events.map { "\($0.kind)|\(String(describing: $0.effectKind))|\($0.amount)|\($0.abilityID)" }
        }
        let first = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            rngSeed: 7,
        )
        let second = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            rngSeed: 7,
        )
        #expect(signature(first.events) == signature(second.events))
    }

    @Test func `outcome branches resolve valid branch effects`() throws {
        let result = try playBranchableCard(
            heroAbilities: [.maul, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Maul",
            rngSeed: 42,
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

    @Test func `resource gain branch resolves correctly`() throws {
        let result = try playBranchableCard(
            heroAbilities: [.tithe, .smite, .hemorrhage],
            companionAbilities: [.bash, .fangs, .bloodthorn],
            abilityNamed: "Tithe",
            rngSeed: 42,
        )
        let gainedGold = result.battle.gold > 0
        let dealtHoly = result.events.contains { $0.keyword == .holy }
        #expect(gainedGold || dealtHoly)
    }
}
