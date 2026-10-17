import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CombatAdmissionRegressionTests {
    @Test func `cards admitted after midturn Freeze cannot bypass pending control`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 20, heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 }, dealOpeningHand: false,
            appliesFightPacing: false,
        )
        battle.insertEffect(.controlMeter(.freeze, 3, 4), to: battle.hero, remainingTurns: 0)
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        battle.insertEffect(.onHitDamage(.freeze, 2), to: battle.enemy, remainingTurns: 0)
        let attack = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)

        _ = try battle.playCard(cardID: attack.id)

        #expect(battle.roster.hasPendingActionSkip(for: battle.hero, keyword: .freeze))
        #expect(battle.hand.cards.isEmpty)
        let generated = BattleCardCombatEngine.deal(.block, owner: .hero, context: &battle)
        #expect(!battle.isCardPlayable(generated))
        #expect(battle.assessCard(generated).denial == .ownerSkipping)
        #expect(throws: BattlePlayError.ownerSkipping) { try battle.playCard(cardID: generated.id) }
    }

    @Test func `damage to a defeated owner cannot detonate Corpse Explosion again`() {
        var profile = CombatantTalentCatalog.profile(for: ["risen_skeleton_deathsdoor_t2_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 0, heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        let enemyHealth = battle.health(of: battle.enemy)

        let result = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.hero, sourceActorID: battle.enemy.id, options: .healthCost,
        ))

        #expect(result == .empty)
        #expect(battle.health(of: battle.enemy) == enemyHealth)
    }

    @Test(arguments: [0, -1])
    func `nonpositive healing cannot manufacture restoration or spend Sprite Touch`(amount: Int) {
        var profile = CombatModifierProfile.zero
        profile.healthRestoredBonus = 5
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.firstHealthRestorationBonusPerTurn = 2
        profile.triggers.onHealDealHoly = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 5, heroModifiers: profile, appliesFightPacing: false,
        )
        let enemyHealth = battle.health(of: battle.enemy)

        let result = battle.resolveHeal(HealRequest(amount: amount, target: battle.hero, sourceActorID: battle.hero.id))

        #expect(result == .empty)
        #expect(battle.health(of: battle.hero) == 5)
        #expect(battle.health(of: battle.enemy) == enemyHealth)
        let positive = battle.resolveHeal(HealRequest(amount: 1, target: battle.hero, sourceActorID: battle.hero.id))
        #expect(positive.healthRestored == 8)
    }

    @Test func `playability rejects a retired card and a different card reusing its ID`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        let card = BattleCardCombatEngine.deal(.block, owner: .hero, context: &battle)
        let impostor = BattleCard(id: card.id, ability: .slash, owner: .companion)
        #expect(battle.isCardPlayable(card))
        #expect(!battle.isCardPlayable(impostor))

        _ = try battle.playCard(cardID: card.id)

        #expect(!battle.isCardPlayable(card))
        #expect(battle.assessCard(card).denial == .cardNotInHand)
    }

    @Test func `Saintfall stops its remaining damage and restoration after its wearer falls`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 1, companionHealth: 5, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 2 }, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let events = battle.recordingEvents { state in
            await CombatTriggerEngine.saintfallAfterBlockBroken(
                on: state.hero, attackerID: state.enemy.id, power: 6, in: &state,
            )
        }

        #expect(!battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 14)
        #expect(!events.contains { $0.effectKind == .instantHeal })
    }
}
