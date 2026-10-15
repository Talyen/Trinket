import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DefeatedSourceDoTRegressionTests {
    @Test(arguments: [false, true], [false, true])
    func `lingering Burn rewards only its living source while preserving ally reactions`(survives: Bool, detonates: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBurnDamageHealLowestAllyFlat = 2
        profile.triggers.onBurnDamageGainBlock = 3
        profile.triggers.onBurnDamageRestoreManaFlat = 1
        var companionProfile = CombatModifierProfile.zero
        companionProfile.triggers.onAllyBurnDamageGainBlock = 1
        let burn = ActiveEffect(id: 100, effect: .burn(8), remainingTurns: 0, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 3),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [burn], heroHealth: survives ? 20 : 0, companionHealth: 5,
            heroMana: 0, heroModifiers: profile, companionModifiers: companionProfile, appliesFightPacing: false,
        )

        if detonates {
            _ = EffectHandlersTestSupport.dispatch(
                .detonateDoT(.burn, 1), source: battle.hero, target: battle.enemy, battle: &battle,
            )
        } else {
            CombatExecutor.run { await EffectHandlers.handler(for: .burn).advanceTurn(burn, on: battle.enemy, in: &battle) }
        }

        let packets = detonates ? 3 : 1
        #expect(battle.health(of: battle.enemy) == (detonates ? 93 : 96))
        #expect(battle.health(of: battle.companion) == (survives ? 5 + 2 * packets : 5))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == (survives ? 3 * packets : 0))
        #expect(battle.mana(of: battle.hero) == (survives ? packets : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.companion.activeEffects) == packets)
    }

    @Test(arguments: [false, true])
    func `Burn damage rewards do not replay natural turn riders`(detonates: Bool) {
        let burn = ActiveEffect(id: 100, effect: .burn(8), remainingTurns: 0, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxMana: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [burn], heroMana: 0,
            heroModifiers: .withTriggers {
                $0.onBurnDamageRestoreManaFlat = 1
                $0.onBurnTickHolyDamage = 5
                $0.onBurnDamageDetonateBleed = true
            }, appliesFightPacing: false,
        )
        battle.appendEffect(.bleed(4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 1)

        if detonates {
            _ = EffectHandlersTestSupport.dispatch(
                .detonateDoT(.burn, 1), source: battle.hero, target: battle.enemy, battle: &battle,
            )
            #expect(battle.health(of: battle.enemy) == 93)
            #expect(battle.mana(of: battle.hero) == 3)
        } else {
            _ = battle.resolveDamage(.doTTick(
                amount: 4, target: battle.enemy, keyword: .burn, sourceActorID: battle.hero.id,
            ))
            #expect(battle.health(of: battle.enemy) == 96)
            #expect(battle.mana(of: battle.hero) == 1)
        }
        #expect(CombatTriggerEngine.totalPotency(of: .bleed, on: battle.enemy, in: battle) == 4)
    }

    @Test(arguments: [false, true])
    func `Blood Money rewards a lethal Bleed tick only while its Rogue survives`(survives: Bool) {
        let bleed = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 1, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 4),
            enemyEffects: [bleed],
            heroHealth: survives ? 10 : 0,
            heroModifiers: CombatantTalentCatalog
                .profile(for: ["rogue_bleed_t2_2"]), appliesFightPacing: false,
        )

        let events = battle.recordingEvents { battle in await EffectHandlers.handler(for: .bleed).advanceTurn(
            bleed, on: battle.enemy, in: &battle,
        ) }

        #expect(battle.health(of: battle.enemy) == 0)
        #expect(battle.gold == (survives ? 5 : 0))
        #expect(events.contains { $0.abilityName == "Blood Money" && $0.amount == 5 } == survives)
    }

    @Test(arguments: [Keyword.poison, .burn])
    func `Bleed converts damage after its source is defeated without granting personal rewards`(conversion: Keyword) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedDamageNextBasicGuaranteedCrit = true
        profile.triggers.onBleedDamageNextBasicCritBonus = 0.35
        profile.triggers.onBleedDamageHealSelf = 2
        if conversion == .poison {
            profile.triggers.onBleedApplyPoison = 2
            profile.triggers.onBleedDealPoisonChancePercent = 1
        } else {
            profile.triggers.onBleedDealBurnDamage = 2
            profile.triggers.onBleedDealBurnChancePercent = 1
        }
        let bleed = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 1, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [bleed],
            heroHealth: 0,
            heroModifiers: profile, appliesFightPacing: false,
        )

        CombatExecutor.run { await EffectHandlers.handler(for: .bleed).advanceTurn(
            bleed, on: battle.enemy, in: &battle,
        ) }

        #expect(battle.health(of: battle.enemy) == 94)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == (conversion == .poison ? 2 : 0))
        #expect(battle.health(of: battle.hero) == 0)
        #expect(!battle.roster.hero.talents.pending.basicGuaranteedCritical)
        #expect(battle.roster.hero.talents.pending.basicCriticalBonus == 0)
    }
}
