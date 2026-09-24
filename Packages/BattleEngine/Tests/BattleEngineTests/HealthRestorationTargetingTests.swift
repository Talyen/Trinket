import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealthRestorationTargetingTests {
    private func battle(
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        heroHealth: Int = 20,
        companionHealth: Int = 1,
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: heroHealth,
            companionHealth: companionHealth,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
        )
        battle.appliesFightPacing = false
        return battle
    }

    @Test func `holy and dodge affixes restore the lowest ally`() {
        let holy = CombatModifierProfile(triggers: CombatTraitTriggers(
            healing: HealingTriggers(holyDamageHealFlat: 3),
        ))
        var holyBattle = battle(heroModifiers: holy)
        _ = CombatTriggerEngine.afterHolyDamageDealt(
            to: holyBattle.enemy, source: holyBattle.hero, in: &holyBattle,
        )
        #expect(holyBattle.health(of: holyBattle.companion) == 4)
        #expect(holyBattle.health(of: holyBattle.hero) == 20)

        let dodge = CombatModifierProfile(triggers: CombatTraitTriggers(
            dodge: DodgeTriggers(dodgeHealFlat: 3),
        ))
        var dodgeBattle = battle(heroModifiers: dodge)
        _ = CombatTriggerEngine.afterDodge(
            by: dodgeBattle.hero, attackerID: dodgeBattle.enemy.id,
            allowsCounterattacks: false, in: &dodgeBattle,
        )
        #expect(dodgeBattle.health(of: dodgeBattle.companion) == 4)
        #expect(dodgeBattle.health(of: dodgeBattle.hero) == 20)
    }

    @Test func `gold affix and talent restoration reach a wounded partner`() {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(
            gold: GoldTriggers(gainGoldBonusHealSelf: 2, goldGainHealChancePercent: 1, goldGainHealAmount: 3),
        ))
        var battle = battle(heroModifiers: profile)
        _ = battle.grantGoldEvent(1, to: battle.hero, abilityName: "Test Gold")
        #expect(battle.health(of: battle.companion) == 6)
        #expect(battle.health(of: battle.hero) == 20)
    }

    @Test func `hibernation uses the bear's Block to heal its lower Health ally`() {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(
            healing: HealingTriggers(endTurnWithBlockHealFlat: 2),
        ))
        var battle = battle(companionModifiers: profile, heroHealth: 1, companionHealth: 20)
        DefensePoolEngine.set(3, on: battle.companion, in: &battle)
        _ = CombatTriggerEngine.atPlayerEndTurn(in: &battle)
        #expect(battle.health(of: battle.hero) == 3)
        #expect(battle.health(of: battle.companion) == 20)
    }

    @Test func `cleanse restoration can heal a different ally`() {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(
            damage: DamageTriggers(criticalChanceBonus: -1),
            healing: HealingTriggers(cleanseSelfHeal: 2, cleanseBonusHeal: 2, purifyingWaters: true),
            cleanse: CleanseTriggers(freshBatch: true),
        ))
        var battle = battle(heroModifiers: profile)
        battle.appendEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 1)
        _ = CleanseOperation.resolve(
            .all(.poison), source: battle.hero, target: battle.hero,
            abilityName: "Cleanse", in: &battle,
        )
        #expect(battle.health(of: battle.companion) == 11)
        #expect(battle.health(of: battle.hero) == 20)
    }

    @Test func `saintfall heals the lowest ally after Block breaks`() {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(
            block: BlockTriggers(blockBrokenSaintfallPower: 6),
        ))
        var battle = battle(heroModifiers: profile)
        DefensePoolEngine.set(1, on: battle.hero, in: &battle)
        _ = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.hero, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .effect(),
        ))
        #expect(battle.health(of: battle.companion) == 7)
    }
}
