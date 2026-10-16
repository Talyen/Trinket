import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DodgeSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `lethal retaliation during a Dodge reward stops later uncommitted rewards`(healsFromGold: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.dodgeGoldFlat = healsFromGold ? 1 : 0
        profile.triggers.gainGoldBonusHealSelf = healsFromGold ? 1 : 0
        profile.triggers.dodgeHealFlat = healsFromGold ? 0 : 1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.onDodgeGrantHeroBlock = 3
        profile.triggers.onDodgePartyMana = 2
        profile.triggers.onDodgeDrawCardForHero = 1
        profile.triggers.dodgeNextStunAttackBonus = 3
        profile.triggers.dodgeNextFreezeAttackBonus = 2
        profile.triggers.dodgeNextBleedAttackBonus = 2
        profile.triggers.dodgeBleedChancePercent = 1
        profile.triggers.dodgeBleedDamage = 2
        profile.triggers.dodgeBurnChancePercent = 1
        profile.triggers.dodgeBurnDamage = 2
        profile.triggers.dodgeApplyPoison = 2
        profile.triggers.onDodgeCounterDamage = 2
        profile.triggers.onDodgeApplyPoisonOrBleed = 2
        profile.triggers.onDodgeAttackerStunBuildup = 2
        profile.triggers.onDodgeDelayAttackerTurn = true
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1, heroMana: 0,
            companionModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
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
        #expect(battle.additionalControlSkipsByCombatantID[battle.enemy.id, default: 0] == 0)
        #expect(battle.mana(of: battle.hero) == (healsFromGold ? 0 : 2))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (healsFromGold ? 0 : 3))
        #expect(battle.heroDeck.abilities.map(\.id) == (healsFromGold ? [Ability.block.id] : []))
        #expect(events.contains { $0.effectKind == .instantHeal && $0.targetID == battle.companion.id })
    }

    @Test func `a surviving Dodge winner still completes healing and ally card support`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onDodgeDrawAndPlayCardChainOnCrit = true
        profile.triggers.dodgeHealFlat = 2
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.firstDodgeDrawForAlly = true
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1),
            companionHealth: 3, companionModifiers: profile, appliesFightPacing: false,
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
