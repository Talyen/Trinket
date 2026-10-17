import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct LeechSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `Leech preserves restoration feedback but stops rewards after lethal healing retaliation`(companionSource: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.leechBlockChancePercent = 1
        profile.triggers.leechThornsWithoutThorns = 3
        profile.triggers.leechBlockBelowHalf = true
        profile.triggers.companionLeechSharePercent = 1
        profile.triggers.leechSharesToHeroPercent = 1
        profile.triggers.firstLeechRestorationShareAlly = true
        profile.triggers.onCompanionLeechRestoreHeroMana = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: companionSource ? 10 : 1,
            companionHealth: companionSource ? 1 : 10, heroMana: 0,
            heroModifiers: companionSource ? .zero : profile,
            companionModifiers: companionSource ? profile : .zero,
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        let source = companionSource ? battle.companion : battle.hero
        let ally = companionSource ? battle.hero : battle.companion
        battle.roster.mutateRuntime(for: source) { $0.hasConsumedDeathsDoor = true }
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let result = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            4, sourceActorID: source.id, target: context.enemy, abilityHasLeech: true, in: &context,
        ) }

        #expect(battle.health(of: source) == 0)
        #expect(battle.health(of: ally) == 10)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(!battle.activeEffects(of: source).contains { $0.effect.kind == .thorns })
        #expect(result.value.healthRestored == 2)
        #expect(result.value.flags.contains(.leeched))
        #expect(result.events.contains { $0.effectKind == .leechHeal && $0.targetID == source.id && $0.amount == 2 })
        #expect(!result.events.contains { $0.effectKind == .thornsApplied })
    }

    private enum FirstShare: CaseIterable, Sendable {
        case symbiosis, companionShare, soulSharing
    }

    @Test(arguments: FirstShare.allCases)
    private func `lethal retaliation from a Leech share stops later shares and ally Mana`(firstShare: FirstShare) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30, maxMana: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 1, heroMana: 0,
            companionModifiers: .withTriggers {
                $0.criticalChanceBonus = -1
                $0.onHealDealHoly = 1
                $0.companionLeechSharePercent = firstShare == .symbiosis ? 1 : 0
                $0.leechSharesToHeroPercent = firstShare == .soulSharing ? 0 : 1
                $0.firstLeechRestorationShareAlly = true
                $0.onCompanionLeechRestoreHeroMana = 2
            }, enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 3 }, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let result = battle.recordingResult { context in await HealingEngine.leechFromDamage(
            8, sourceActorID: context.companion.id, target: context.enemy, abilityHasLeech: true, in: &context,
        ) }

        #expect(battle.health(of: battle.companion) == 0)
        #expect(battle.health(of: battle.hero) == 14)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 18)
        #expect(result.value.healthRestored == 4)
        #expect(result.events.contains { $0.effectKind == .leechHeal && $0.amount == 4 })
    }
}
