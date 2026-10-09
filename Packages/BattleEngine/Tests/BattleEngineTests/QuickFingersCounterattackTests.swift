import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct QuickFingersCounterattackTests {
    @Test(arguments: [false, true])
    func `a critical counterattack has its own theft reward allowance across all hits`(jackpot: Bool) {
        var profile = CombatantTalentCatalog.profile(for: jackpot
            ? ["wildcard_gold_t2_1"] : ["rogue_gold_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 100, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.slash, .block, .stab])
        let theft = Ability(
            id: "critical-double-theft", name: "Critical Double Theft", tier: .basic,
            damageComponents: [DamageComponent(1), DamageComponent(1)],
            targetedEffects: [TargetedEffect(.resourceGain(.gold, 2)), TargetedEffect(.resourceGain(.gold, 2))],
            stealsGold: true,
            guaranteedCriticalCondition: .enemyNotBurning,
        )
        let serial = battle.resolution.beginCard(actorID: battle.hero.id)
        defer { battle.resolution.endCard(serial) }

        let parent = BattleTurnEngine.performAction(
            ability: theft, actor: battle.hero, abilityTarget: battle.enemy, origin: .card, context: &battle,
        )
        #expect(battle.gold == (jackpot ? 9 : 4))
        #expect(parent.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Quick Fingers" } == (jackpot ? 0 : 1))

        let counterattack = BattleTurnEngine.performAction(
            ability: theft, actor: battle.hero, abilityTarget: battle.enemy, origin: .counterattack, context: &battle,
        )

        #expect(counterattack.count { $0.kind == .abilityDamage && $0.isCritical } == 2)
        #expect(battle.gold == (jackpot ? 18 : 8))
        #expect(counterattack.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Quick Fingers" } == (jackpot ? 0 : 1))
        #expect(battle.hand.cards.map(\.ability.id) == (jackpot ? [] : [Ability.slash.id, Ability.block.id]))
    }

    @Test(arguments: [false, true], [false, true])
    func `critical Blackjack theft rewards include counterattacks`(counterattack: Bool, jackpot: Bool) throws {
        var profile = CombatantTalentCatalog.profile(for: jackpot
            ? ["wildcard_gold_t2_1"] : ["rogue_gold_t3_2", "rogue_gold_t2_1"])
        profile.triggers.criticalChanceBonus = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 20, heroModifiers: profile, rngSeed: 0, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.slash, .block])
        let events: [ActionEvent]
        if counterattack {
            events = BattleTurnEngine.performAction(
                ability: .blackjack, actor: battle.hero, abilityTarget: battle.enemy,
                origin: .counterattack, context: &battle,
            )
        } else {
            let card = BattleCardCombatEngine.deal(.blackjack, owner: .hero, context: &battle)
            events = try battle.playCard(cardID: card.id)
        }

        #expect(events.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(battle.gold == 7)
        #expect(events.count { $0.effectKind == .cardsDrawn && $0.abilityName == "Quick Fingers" } == (jackpot ? 0 : 1))
        #expect(battle.hand.cards.map(\.ability.id) == (jackpot ? [] : [Ability.slash.id]))
    }

    @Test(arguments: [false, true])
    func `a noncritical counterattack cannot borrow its parent card Critical Hit`(jackpot: Bool) {
        var profile = CombatantTalentCatalog.profile(for: jackpot
            ? ["wildcard_gold_t2_1"] : ["rogue_gold_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 20, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.appendEffect(.controlMeter(.stun, 4, 4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let serial = battle.resolution.beginCard(actorID: battle.hero.id)
        defer { battle.resolution.endCard(serial) }
        battle.resolution.mutateCardTalents { $0.didCriticalHit = true }

        let events = BattleTurnEngine.performAction(
            ability: .blackjack, actor: battle.hero, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )

        #expect(!events.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(battle.gold == 2)
        #expect(!events.contains { $0.effectKind == .cardsDrawn && $0.abilityName == "Quick Fingers" })
        #expect(battle.hand.cards.isEmpty)
    }
}
