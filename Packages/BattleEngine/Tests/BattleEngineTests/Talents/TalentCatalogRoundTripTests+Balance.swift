import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `golden opportunity limits multiple gains and empty decks`() {
        var battle = heroTalentBattle("fox_gold_t2_1")
        battle.heroDeck = CombatDeck(abilities: [.slash, .stab, .bash])
        for amount in [4, 5, 10] {
            let events = battle.grantGoldEvent(amount, to: battle.hero, abilityName: "Gold")
            #expect(events.contains { $0.effectKind == .cardsDrawn } == (amount == 5))
        }
        battle.turnCount += 1
        let renewed = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        #expect(renewed.contains { $0.effectKind == .cardsDrawn })
        battle.turnCount += 1
        battle.heroDeck = CombatDeck(abilities: [])
        _ = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        battle.heroDeck = CombatDeck(abilities: [.slash])
        let spent = battle.grantGoldEvent(5, to: battle.hero, abilityName: "Gold")
        #expect(!spent.contains { $0.effectKind == .cardsDrawn })
    }

    @Test(arguments: ["ignored", "dodged", "blocked", "aura", "ray"])
    func `shadow camouflage uses attack attempts rather than health loss`(scenario: String) {
        var battle = capstoneBattle(companion: ["panther_dodge_t3_1"])
        battle.heroTalents.enemyTurnActive = true
        if scenario == "dodged" {
            battle.appendEffect(.evadeNextHit, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        }
        if scenario == "blocked" {
            DefensePoolEngine.set(20, on: battle.companion, in: &battle)
        }
        if scenario == "ray" {
            _ = BattleTurnEngine.performAction(
                ability: .rayOfFrost, actor: battle.enemy, abilityTarget: battle.companion, context: &battle,
            )
        } else if scenario != "ignored" {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
                options: scenario == "aura" ? .reaction() : .attack(),
            ))
        }
        _ = CombatTriggerEngine.afterHeroTalentEnemyTurn(in: &battle)
        let qualifies = scenario == "ignored" || scenario == "aura"
        #expect(battle.roster.companion.talents.pending.shadowCamouflageBonus == (qualifies ? 1 : 0))
    }

    @Test(arguments: [Keyword.physical, .holy, .freeze])
    func `shadow camouflage refreshes and adds only one generic attack bonus`(keyword: Keyword) {
        var battle = capstoneBattle(companion: ["panther_dodge_t3_1"])
        for _ in 0 ..< 2 {
            _ = CombatTriggerEngine.afterHeroTalentEnemyTurn(in: &battle)
        }
        for expected in [4, 3] {
            let result = battle.resolveDamage(DamageRequest(
                amount: 3, target: battle.enemy, keyword: keyword, sourceActorID: battle.companion.id,
                options: .attack(accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            ))
            #expect(result.healthLost == expected)
        }
    }
}
