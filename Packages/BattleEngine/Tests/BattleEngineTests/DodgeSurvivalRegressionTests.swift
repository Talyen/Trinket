import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DodgeSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `lethal retaliation during a Dodge reward stops later uncommitted rewards`(healsFromGold: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1, heroMana: 0,
            companionModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.dodgeGoldFlat = healsFromGold ? 1 : 0
                $0.gainGoldBonusHealSelf = healsFromGold ? 1 : 0
                $0.dodgeHealFlat = healsFromGold ? 0 : 1
                $0.onHealDealHoly = 1
                $0.onDodgeGrantHeroBlock = 3
                $0.onDodgePartyMana = 2
                $0.onDodgeDrawCardForHero = 1
                $0.dodgeNextStunAttackBonus = 3
                $0.dodgeNextFreezeAttackBonus = 2
                $0.dodgeNextBleedAttackBonus = 2
                $0.dodgeBleedChancePercent = 1
                $0.dodgeBleedDamage = 2
                $0.dodgeBurnChancePercent = 1
                $0.dodgeBurnDamage = 2
                $0.dodgeApplyPoison = 2
                $0.onDodgeCounterDamage = 2
                $0.onDodgeApplyPoisonOrBleed = 2
                $0.onDodgeAttackerStunBuildup = 2
                $0.onDodgeDelayAttackerTurn = true
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.heroDeck = CombatDeck(abilities: [.block])
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
            by: battle.companion, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.roster.companion.talents.pending.nextDodgeStunAttackBonus == nil)
        #expect(battle.roster.companion.talents.pending.nextDodgeFreezeAttackBonus == nil)
        #expect(battle.roster.companion.talents.pending.nextDodgeBleedAttackBonus == nil)
        #expect(battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.enemy) == 100)
        // Only the committed healing's Holy ping can consume enemy Block.
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 19)
        #expect(battle.activeEffects(of: battle.enemy).allSatisfy { !$0.effect.isRemovableDebuff })
        #expect(battle.roster.enemy.talents.battle.actionDelays == 0)
        #expect(battle.mana(of: battle.hero) == (healsFromGold ? 0 : 2))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (healsFromGold ? 0 : 3))
        #expect(battle.heroDeck.abilities.map(\.id) == (healsFromGold ? [Ability.block.id] : []))
        #expect(events.contains { $0.effectKind == .instantHeal && $0.targetID == battle.companion.id })
    }

    @Test func `a surviving Dodge winner still completes healing and ally card support`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1),
            companionHealth: 3, companionModifiers: .withTriggers {
                $0.onDodgeDrawAndPlayCardChainOnCrit = true
                $0.dodgeHealFlat = 2
                $0.criticalChanceBonus = -1
                $0.firstDodgeDrawForAlly = true
            }, appliesFightPacing: false,
        )
        battle.companionDeck = CombatDeck(abilities: [.stab])
        battle.heroDeck = CombatDeck(abilities: [.block])

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterDodge(
            by: battle.companion, attackerID: battle.enemy.id, in: &battle,
        ) }

        #expect(!battle.roster.enemy.isAlive)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(battle.heroDeck.abilities.isEmpty)
        #expect(events.contains { $0.abilityName == "Tailwind" && $0.effectKind == .cardsDrawn })
    }
}
