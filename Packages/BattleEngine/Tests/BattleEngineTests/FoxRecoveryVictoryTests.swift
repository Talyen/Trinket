import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct FoxRecoveryVictoryTests {
    @Test(arguments: [1, 100])
    func `Golden Recovery restores Health after Steal even on victory`(enemyHealth: Int) throws {
        var profile = CombatantTalentCatalog.profile(for: ["fox_gold_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: enemyHealth, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 4
        let card = BattleCardCombatEngine.deal(.steal, owner: .companion, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(battle.isEnemyDefeated == (enemyHealth == 1))
        #expect(battle.gold == 2)
        #expect(battle.health(of: battle.companion) == 7)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(events.count {
            $0.effectKind == .instantHeal && $0.abilityName == "Golden Recovery"
                && $0.amount == 3 && $0.targetID == battle.companion.id
        } == 1)
    }

    @Test(arguments: [1, 100])
    func `Stolen Breath restores Health after a winning Laughing Guard Dodge`(enemyHealth: Int) throws {
        var profile = CombatantTalentCatalog.profile(for: ["fox_dodge_t3_2"])
        profile.triggers.criticalChanceBonus = -1
        let item = try #require(GameContent.unique(matching: "laughing_guard"))
        let signature = try #require(item.affixPowers?.first)
        profile.merge(signature.modifiers)
        signature.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: enemyHealth, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 4
        DefensePoolEngine.set(8, on: battle.companion, in: &battle)
        battle.appendEffect(.evadeNextHit, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        let attack = Ability(
            id: "fox-recovery-enemy-attack", name: "Enemy Attack", tier: .basic,
            directDamage: 5, criticalChanceBonus: -1,
        )

        let events = BattleTurnEngine.performAction(
            ability: attack, actor: battle.enemy, abilityTarget: battle.companion, context: &battle,
        )

        #expect(events.contains { $0.effectKind == .dodgeApplied })
        #expect(battle.health(of: battle.enemy) == max(0, enemyHealth - 4))
        #expect(battle.isEnemyDefeated == (enemyHealth == 1))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 4)
        #expect(battle.health(of: battle.companion) == 7)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(events.count {
            $0.effectKind == .instantHeal && $0.abilityName == "Stolen Breath"
                && $0.amount == 3 && $0.targetID == battle.companion.id
        } == 1)
    }
}
