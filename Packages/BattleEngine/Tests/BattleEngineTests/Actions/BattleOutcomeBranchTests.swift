import Testing
import TrinketContent
import TrinketContentTestSupport
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
        }
        #expect(seenKeywords == [.block, .thorns, .health])
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
